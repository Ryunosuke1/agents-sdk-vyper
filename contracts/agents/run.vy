# SPDX-License-Identifier: MIT
# @version ^0.3.3

# Runner - エージェント実行を管理するためのメインコントラクト
# このコントラクトは、複数のエージェント、ツール、ガードレールを調整して実行します

import contracts.agents.agent.interface as AgentInterface
import contracts.agents.guardrails.interface as GuardrailInterface
import contracts.agents.handoffs.interface as HandoffInterface

# 実行設定の構造体
struct RunConfig:
    # 最大ターン数
    max_turns: uint256
    # 入力ガードレールを有効にするかどうか
    enable_input_guardrails: bool
    # 出力ガードレールを有効にするかどうか
    enable_output_guardrails: bool
    # トレーシングを有効にするかどうか
    enable_tracing: bool

# 実行結果の構造体
struct RunResult:
    # 実行ID
    run_id: bytes32
    # 開始エージェントのアドレス
    start_agent: address
    # 最終エージェントのアドレス
    final_agent: address
    # 実行の最終出力
    final_output: String[1024]
    # ステップの数
    step_count: uint256
    # ハンドオフの数
    handoff_count: uint256
    # タイムスタンプ
    timestamp: uint256
    # 完了しているかどうか
    completed: bool

# コントラクト変数
owner: public(address)
agents: public(HashMap[bytes32, address])
agent_ids: public(DynArray[bytes32, 50])
input_guardrails: public(HashMap[bytes32, address])
input_guardrail_ids: public(DynArray[bytes32, 20])
output_guardrails: public(HashMap[bytes32, address])
output_guardrail_ids: public(DynArray[bytes32, 20])
handoff_manager: public(address)
results: public(HashMap[bytes32, RunResult])
result_ids: public(DynArray[bytes32, 100])
default_config: public(RunConfig)

# イベント
event AgentRegistered:
    agentId: bytes32
    agentAddress: address
    agentName: String[64]

event GuardrailRegistered:
    guardrailId: bytes32
    guardrailAddress: address
    guardrailName: String[64]
    guardrailType: GuardrailInterface.GuardrailType

event RunStarted:
    runId: bytes32
    agentId: bytes32
    input: String[1024]

event RunCompleted:
    runId: bytes32
    finalAgentId: bytes32
    finalOutput: String[1024]
    stepCount: uint256
    handoffCount: uint256

event HandoffOccurred:
    runId: bytes32
    fromAgentId: bytes32
    toAgentId: bytes32
    handoffId: bytes32

event GuardrailTriggered:
    runId: bytes32
    guardrailId: bytes32
    validationId: bytes32
    reason: String[256]

@external
def __init__(handoff_manager_address: address):
    """
    @notice Runnerコントラクトの初期化
    @param handoff_manager_address ハンドオフマネージャーのアドレス
    """
    self.owner = msg.sender
    self.handoff_manager = handoff_manager_address
    
    # デフォルト設定の初期化
    self.default_config = RunConfig({
        max_turns: 10,
        enable_input_guardrails: True,
        enable_output_guardrails: True,
        enable_tracing: True
    })

@external
def register_agent(agent_address: address) -> bytes32:
    """
    @notice エージェントを登録する
    @param agent_address エージェントコントラクトのアドレス
    @return エージェントID
    """
    # オーナーのみが登録可能
    assert msg.sender == self.owner, "Only owner can register agents"
    
    # エージェントインスタンスの取得
    agent: AgentInterface.AgentInterface = AgentInterface.AgentInterface(agent_address)
    
    # エージェント名の取得
    agent_name: String[64] = agent.name()
    
    # エージェントIDの生成
    agent_id: bytes32 = keccak256(concat(
        convert(block.timestamp, bytes32),
        convert(len(self.agent_ids), bytes32),
        convert(agent_address, bytes32)
    ))
    
    # エージェントの登録
    self.agents[agent_id] = agent_address
    self.agent_ids.append(agent_id)
    
    # イベントの発行
    log AgentRegistered(agent_id, agent_address, agent_name)
    
    return agent_id

@external
def register_guardrail(guardrail_address: address) -> bytes32:
    """
    @notice ガードレールを登録する
    @param guardrail_address ガードレールコントラクトのアドレス
    @return ガードレールID
    """
    # オーナーのみが登録可能
    assert msg.sender == self.owner, "Only owner can register guardrails"
    
    # ガードレールインスタンスの取得
    guardrail: GuardrailInterface.GuardrailInterface = GuardrailInterface.GuardrailInterface(guardrail_address)
    
    # ガードレール情報の取得
    guardrail_name: String[64] = guardrail.name()
    guardrail_type: GuardrailInterface.GuardrailType = guardrail.guardrail_type()
    
    # ガードレールIDの生成
    guardrail_id: bytes32 = keccak256(concat(
        convert(block.timestamp, bytes32),
        convert(len(self.input_guardrail_ids) + len(self.output_guardrail_ids), bytes32),
        convert(guardrail_address, bytes32)
    ))
    
    # ガードレールの登録（タイプに応じて適切なリストに追加）
    if guardrail_type == GuardrailInterface.GuardrailType.INPUT:
        self.input_guardrails[guardrail_id] = guardrail_address
        self.input_guardrail_ids.append(guardrail_id)
    else:  # OUTPUT
        self.output_guardrails[guardrail_id] = guardrail_address
        self.output_guardrail_ids.append(guardrail_id)
    
    # イベントの発行
    log GuardrailRegistered(guardrail_id, guardrail_address, guardrail_name, guardrail_type)
    
    return guardrail_id

@external
def set_default_config(config: RunConfig):
    """
    @notice デフォルトの実行設定を設定する
    @param config 新しいデフォルト設定
    """
    # オーナーのみが設定可能
    assert msg.sender == self.owner, "Only owner can set default config"
    
    self.default_config = config

@external
def run(agent_id: bytes32, input: String[1024], config: RunConfig = empty(RunConfig)) -> bytes32:
    """
    @notice エージェントを実行する
    @param agent_id 実行するエージェントのID
    @param input 入力テキスト
    @param config 実行設定（省略可能）
    @return 実行ID
    """
    # エージェントの存在確認
    assert agent_id in self.agent_ids, "Agent not found"
    
    # 実行設定の取得
    run_config: RunConfig
    if config.max_turns == 0:  # 設定が指定されていない場合はデフォルト値を使用
        run_config = self.default_config
    else:
        run_config = config
    
    # 実行IDの生成
    run_id: bytes32 = keccak256(concat(
        convert(block.timestamp, bytes32),
        convert(len(self.result_ids), bytes32),
        convert(msg.sender, bytes32),
        convert(agent_id, bytes32)
    ))
    
    # 入力ガードレールの実行（有効な場合）
    if run_config.enable_input_guardrails:
        for i in range(20):  # 最大20個のガードレール
            if i >= len(self.input_guardrail_ids):
                break
                
            guardrail_id: bytes32 = self.input_guardrail_ids[i]
            guardrail_address: address = self.input_guardrails[guardrail_id]
            guardrail: GuardrailInterface.GuardrailInterface = GuardrailInterface.GuardrailInterface(guardrail_address)
            
            # 入力の検証
            validation_id: bytes32 = guardrail.validate_input(input)
            
            # 検証結果が即時に利用可能な場合（非同期実装の場合は別の方法が必要）
            if guardrail.is_validation_complete(validation_id):
                validation_result: GuardrailInterface.GuardrailValidationInfo = guardrail.get_validation_result(validation_id)
                
                # ガードレールが失敗した場合は実行を中止
                if validation_result.result == GuardrailInterface.GuardrailResult.FAIL:
                    # 失敗イベントを発行
                    log GuardrailTriggered(run_id, guardrail_id, validation_id, validation_result.reason)
                    
                    # エラー結果を設定
                    result: RunResult = RunResult({
                        run_id: run_id,
                        start_agent: self.agents[agent_id],
                        final_agent: self.agents[agent_id],
                        final_output: concat("Input validation failed: ", validation_result.reason),
                        step_count: 0,
                        handoff_count: 0,
                        timestamp: block.timestamp,
                        completed: True
                    })
                    
                    self.results[run_id] = result
                    self.result_ids.append(run_id)
                    
                    return run_id
    
    # エージェントアドレスの取得
    agent_address: address = self.agents[agent_id]
    agent: AgentInterface.AgentInterface = AgentInterface.AgentInterface(agent_address)
    
    # エージェントを実行
    agent_run_id: bytes32 = agent.run(input)
    
    # 実行結果の初期化
    result: RunResult = RunResult({
        run_id: run_id,
        start_agent: agent_address,
        final_agent: agent_address,
        final_output: "",
        step_count: 0,
        handoff_count: 0,
        timestamp: block.timestamp,
        completed: False
    })
    
    # 結果の保存
    self.results[run_id] = result
    self.result_ids.append(run_id)
    
    # イベントの発行
    log RunStarted(run_id, agent_id, input)
    
    return run_id

@external
def process_run(run_id: bytes32) -> bool:
    """
    @notice 実行の処理を進める
    @param run_id 実行ID
    @return 実行が完了した場合はTrue
    """
    # 実行の存在確認
    assert run_id in self.result_ids, "Run not found"
    
    # 実行結果の取得
    result: RunResult = self.results[run_id]
    
    # すでに完了している場合
    if result.completed:
        return True
    
    # 現在のエージェントの取得
    current_agent: AgentInterface.AgentInterface = AgentInterface.AgentInterface(result.final_agent)
    
    # エージェントの実行ステップを処理
    is_complete: bool = current_agent.process_step(run_id)
    
    if is_complete:
        # 結果の取得
        output: String[1024] = current_agent.get_result(run_id)
        
        # 出力ガードレールの実行（有効な場合）
        # 注: この例では簡略化のため、出力ガードレールの処理は省略
        
        # 結果の更新
        result.final_output = output
        result.completed = True
        result.step_count += 1
        self.results[run_id] = result
        
        # イベントの発行
        log RunCompleted(run_id, run_id, output, result.step_count, result.handoff_count)
        
        return True
    
    # まだ完了していない場合
    result.step_count += 1
    self.results[run_id] = result
    
    return False

@external
@view
def get_result(run_id: bytes32) -> RunResult:
    """
    @notice 実行結果を取得する
    @param run_id 実行ID
    @return 実行結果
    """
    assert run_id in self.result_ids, "Run not found"
    return self.results[run_id]

@external
@view
def is_run_complete(run_id: bytes32) -> bool:
    """
    @notice 実行が完了したかどうかを確認する
    @param run_id 実行ID
    @return 実行が完了した場合はTrue
    """
    assert run_id in self.result_ids, "Run not found"
    return self.results[run_id].completed

@external
@view
def get_agent_address(agent_id: bytes32) -> address:
    """
    @notice エージェントIDからエージェントアドレスを取得する
    @param agent_id エージェントID
    @return エージェントコントラクトのアドレス
    """
    assert agent_id in self.agent_ids, "Agent not found"
    return self.agents[agent_id]

@external
@view
def get_agent_count() -> uint256:
    """
    @notice 登録されているエージェントの数を取得する
    @return エージェントの数
    """
    return len(self.agent_ids)

@external
@view
def get_agent_id_at(index: uint256) -> bytes32:
    """
    @notice 指定インデックスのエージェントIDを取得する
    @param index インデックス
    @return エージェントID
    """
    assert index < len(self.agent_ids), "Index out of bounds"
    return self.agent_ids[index]