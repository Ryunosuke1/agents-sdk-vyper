# SPDX-License-Identifier: MIT
# @version ^0.3.3

# run.vy - Agents SDKのメインエントリーポイント
# このコントラクトはユーザーがエージェントを簡単に実行するためのシンプルなインターフェースを提供します

import contracts.agents.agent.interface as AgentInterface
import contracts.agents.run as Runner

# AgentRunner - エージェント実行のためのシンプルなエントリーポイント
# これによりユーザーは簡単にエージェントを作成・実行できます

# コントラクト変数
owner: public(address)
runner: public(Runner.Runner)
default_agents: public(HashMap[String[64], bytes32])  # 名前 => エージェントID

# イベント
event DefaultAgentSet:
    name: String[64]
    agentId: bytes32

@external
def __init__(runner_address: address):
    """
    @notice コントラクトの初期化
    @param runner_address Runnerコントラクトのアドレス
    """
    self.owner = msg.sender
    self.runner = Runner.Runner(runner_address)

@external
def set_default_agent(name: String[64], agent_id: bytes32):
    """
    @notice デフォルトエージェントを設定する
    @param name エージェント名
    @param agent_id エージェントID
    """
    assert msg.sender == self.owner, "Only owner can set default agents"
    
    # エージェントIDが有効かどうかをチェック
    agent_address: address = self.runner.get_agent_address(agent_id)
    
    # 設定を保存
    self.default_agents[name] = agent_id
    
    # イベントの発行
    log DefaultAgentSet(name, agent_id)

@external
def run_agent(agent_id: bytes32, input: String[1024]) -> bytes32:
    """
    @notice エージェントを実行する
    @param agent_id 実行するエージェントのID
    @param input 入力テキスト
    @return 実行ID
    """
    # Runnerを通じてエージェントを実行
    return self.runner.run(agent_id, input)

@external
def run_agent_by_name(name: String[64], input: String[1024]) -> bytes32:
    """
    @notice 名前でエージェントを実行する
    @param name 実行するエージェントの名前
    @param input 入力テキスト
    @return 実行ID
    """
    # エージェントIDの取得
    agent_id: bytes32 = self.default_agents[name]
    assert agent_id != empty(bytes32), "Agent not found"
    
    # エージェントの実行
    return self.runner.run(agent_id, input)

@external
def process_run(run_id: bytes32) -> bool:
    """
    @notice 実行の処理を進める
    @param run_id 実行ID
    @return 実行が完了した場合はTrue
    """
    return self.runner.process_run(run_id)

@external
@view
def get_result(run_id: bytes32) -> String[1024]:
    """
    @notice 実行結果を取得する
    @param run_id 実行ID
    @return 実行結果のテキスト
    """
    result: Runner.RunResult = self.runner.get_result(run_id)
    return result.final_output

@external
@view
def is_run_complete(run_id: bytes32) -> bool:
    """
    @notice 実行が完了したかどうかを確認する
    @param run_id 実行ID
    @return 実行が完了した場合はTrue
    """
    return self.runner.is_run_complete(run_id)

@external
@view
def get_available_agents() -> DynArray[String[64], 50]:
    """
    @notice 利用可能なエージェントの名前リストを取得する
    @return エージェント名の配列
    """
    # 注: 動的にこれを実装するためには、エージェント名の一覧を保持する必要があります
    # この例では簡略化のため、簡単な実装を示しています
    names: DynArray[String[64], 50] = []
    
    # このメソッドは実際の実装では、保存されているエージェント名の一覧を返すべきです
    return names