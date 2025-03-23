# SPDX-License-Identifier: MIT
# @version ^0.3.3

# AgentImpl - OpenAI Agents SDKのメインエージェント実装
# このコントラクトは、AIモデルと対話し、ツールを実行するエージェントの中核機能を提供します

import contracts.agents.agent.interface as AgentInterface
import contracts.agents.models.interface as ModelInterface
import contracts.agents.tools.interface as ToolInterface

interface ToolRegistryInterface:
    def get_tool_count() -> uint256: view
    def get_tool_id_at(index: uint256) -> bytes32: view
    def get_tool_address(tool_id: bytes32) -> address: view
    def get_tool_id_by_name(tool_name: String[64]) -> bytes32: view

# 実行ステップの種類を表す列挙型
enum StepType:
    # MODEL_CALL: AIモデルを呼び出す
    MODEL_CALL
    # TOOL_CALL: ツールを呼び出す
    TOOL_CALL
    # COMPLETE: 完了
    COMPLETE

# 実行ステップを追跡するための構造体
struct ExecutionStep:
    step_type: StepType
    response_id: bytes32
    tool_id: bytes32
    tool_execution_id: bytes32
    completed: bool
    output: String[1024]

# 実行履歴を追跡するための構造体
struct RunState:
    current_step_index: uint256
    steps: DynArray[ExecutionStep, 20]
    final_output: String[1024]
    completed: bool
    max_steps: uint256

# エージェントの基本設定を保持するための構造体
struct AgentConfig:
    name: String[64]
    instructions: String[1024]
    tool_use_behavior: AgentInterface.ToolUseBehavior

# コントラクト変数
owner: public(address)
state: public(AgentInterface.AgentState)
config: public(AgentConfig)
model: public(ModelInterface.ModelInterface)
tool_registry: public(ToolRegistryInterface)
runs: public(HashMap[bytes32, RunState])
run_ids: public(DynArray[bytes32, 100])

# イベント
event AgentInitialized:
    name: String[64]
    instructions: String[1024]

event RunStarted:
    runId: bytes32
    input: String[1024]

event RunStepCompleted:
    runId: bytes32
    stepIndex: uint256
    stepType: StepType
    output: String[1024]

event RunCompleted:
    runId: bytes32
    finalOutput: String[1024]

@external
def __init__(
    _name: String[64],
    _instructions: String[1024],
    _model_address: address,
    _tool_registry_address: address,
    _tool_use_behavior: AgentInterface.ToolUseBehavior
):
    """
    @notice エージェントコントラクトの初期化
    @param _name エージェントの名前
    @param _instructions エージェントの指示
    @param _model_address AIモデルコントラクトのアドレス
    @param _tool_registry_address ツールレジストリコントラクトのアドレス
    @param _tool_use_behavior ツール使用のふるまい
    """
    self.owner = msg.sender
    self.state = AgentInterface.AgentState.IDLE
    
    self.config = AgentConfig({
        name: _name,
        instructions: _instructions,
        tool_use_behavior: _tool_use_behavior
    })
    
    self.model = ModelInterface.ModelInterface(_model_address)
    self.tool_registry = ToolRegistryInterface(_tool_registry_address)
    
    log AgentInitialized(_name, _instructions)

@external
@view
def name() -> String[64]:
    """
    @notice エージェントの名前を取得
    @return エージェント名
    """
    return self.config.name

@external
@view
def instructions() -> String[1024]:
    """
    @notice エージェントの指示を取得
    @return エージェントへの指示
    """
    return self.config.instructions

@external
@view
def tool_use_behavior() -> AgentInterface.ToolUseBehavior:
    """
    @notice エージェントのツール使用ふるまいを取得
    @return ツール使用のふるまい
    """
    return self.config.tool_use_behavior

@external
@view
def get_tool_count() -> uint256:
    """
    @notice 登録されているツールの数を取得
    @return ツールの数
    """
    return self.tool_registry.get_tool_count()

@external
@view
def get_tool_id(index: uint256) -> address:
    """
    @notice 指定インデックスのツールIDを取得
    @param index ツールインデックス
    @return ツールID
    """
    tool_id: bytes32 = self.tool_registry.get_tool_id_at(index)
    return self.tool_registry.get_tool_address(tool_id)

@external
def run(input: String[1024]) -> bytes32:
    """
    @notice エージェントを実行する
    @param input ユーザー入力
    @return 実行ID
    """
    # 実行状態のチェック
    assert self.state == AgentInterface.AgentState.IDLE, "Agent is busy"
    
    # 実行IDの生成
    run_id: bytes32 = keccak256(concat(
        convert(block.timestamp, bytes32),
        convert(len(self.run_ids), bytes32),
        convert(msg.sender, bytes32)
    ))
    
    # 実行状態の初期化
    run_state: RunState = RunState({
        current_step_index: 0,
        steps: [],
        final_output: "",
        completed: False,
        max_steps: 10
    })
    
    # 最初のステップとしてモデル呼び出しを追加
    first_step: ExecutionStep = ExecutionStep({
        step_type: StepType.MODEL_CALL,
        response_id: empty(bytes32),
        tool_id: empty(bytes32),
        tool_execution_id: empty(bytes32),
        completed: False,
        output: ""
    })
    
    run_state.steps.append(first_step)
    
    # 実行状態を保存
    self.runs[run_id] = run_state
    self.run_ids.append(run_id)
    
    # エージェント状態の更新
    self.state = AgentInterface.AgentState.PROCESSING
    
    # AIモデルへの最初の呼び出しを実行
    response_id: bytes32 = self.model.get_response(
        self.config.instructions,
        input,
        ModelInterface.ModelTracing.ENABLED
    )
    
    # 応答IDを保存
    self.runs[run_id].steps[0].response_id = response_id
    
    # イベントの発行
    log RunStarted(run_id, input)
    
    return run_id

@external
def process_step(run_id: bytes32) -> bool:
    """
    @notice 実行ステップを処理する
    @param run_id 実行ID
    @return 実行が完了した場合はTrue
    """
    # 実行の存在チェック
    assert run_id in self.run_ids, "Run not found"
    
    # 実行状態の取得
    run_state: RunState = self.runs[run_id]
    
    # 実行がすでに完了している場合
    if run_state.completed:
        return True
    
    # 現在のステップインデックスの取得
    current_index: uint256 = run_state.current_step_index
    
    # ステップの最大数を超えている場合
    if current_index >= run_state.max_steps:
        run_state.completed = True
        self.runs[run_id] = run_state
        self.state = AgentInterface.AgentState.IDLE
        return True
    
    # 現在のステップの取得
    current_step: ExecutionStep = run_state.steps[current_index]
    
    # ステップがすでに完了している場合は次のステップを設定
    if current_step.completed:
        # 次のステップを決定
        self._prepare_next_step(run_id)
        return False
    
    # ステップの種類に応じて処理
    if current_step.step_type == StepType.MODEL_CALL:
        # モデル呼び出しの処理
        self._process_model_call(run_id, current_index)
    elif current_step.step_type == StepType.TOOL_CALL:
        # ツール呼び出しの処理
        self._process_tool_call(run_id, current_index)
    elif current_step.step_type == StepType.COMPLETE:
        # 実行の完了
        run_state.completed = True
        self.runs[run_id] = run_state
        self.state = AgentInterface.AgentState.IDLE
        
        # イベントの発行
        log RunCompleted(run_id, run_state.final_output)
        
        return True
    
    return False

@internal
def _process_model_call(run_id: bytes32, step_index: uint256):
    """
    @notice モデル呼び出しのステップを処理する
    @param run_id 実行ID
    @param step_index ステップインデックス
    """
    # 実行状態の取得
    run_state: RunState = self.runs[run_id]
    current_step: ExecutionStep = run_state.steps[step_index]
    
    # モデルからのレスポンスを取得
    response_text: String[1024] = self.model.get_response_text(current_step.response_id)
    
    # レスポンスがまだない場合は、処理を終了
    if len(response_text) == 0:
        return
    
    # レスポンステキストを保存
    current_step.output = response_text
    current_step.completed = True
    run_state.steps[step_index] = current_step
    
    # ツール呼び出しのチェック
    has_tool_call: bool = False
    tool_name: String[64] = ""
    
    # すべての登録済みツールをチェック
    for i in range(100):  # 最大100個のツールをサポート
        if i >= self.tool_registry.get_tool_count():
            break
        
        tool_id: bytes32 = self.tool_registry.get_tool_id_at(i)
        tool_address: address = self.tool_registry.get_tool_address(tool_id)
        tool: ToolInterface.ToolInterface = ToolInterface.ToolInterface(tool_address)
        
        # このツールが呼び出されるかどうかをチェック
        if self.model.calls_tool(current_step.response_id, tool.name()):
            has_tool_call = True
            tool_name = tool.name()
            
            # ツール呼び出し情報を保存
            current_step.tool_id = tool_id
            break
    
    # ツール呼び出しがある場合
    if has_tool_call:
        # ツール呼び出しステップを追加
        tool_step: ExecutionStep = ExecutionStep({
            step_type: StepType.TOOL_CALL,
            response_id: current_step.response_id,
            tool_id: current_step.tool_id,
            tool_execution_id: empty(bytes32),
            completed: False,
            output: ""
        })
        
        run_state.steps.append(tool_step)
        run_state.current_step_index += 1
    else:
        # ツール呼び出しがない場合は最終出力として処理
        run_state.final_output = response_text
        
        # 完了ステップを追加
        complete_step: ExecutionStep = ExecutionStep({
            step_type: StepType.COMPLETE,
            response_id: empty(bytes32),
            tool_id: empty(bytes32),
            tool_execution_id: empty(bytes32),
            completed: False,
            output: ""
        })
        
        run_state.steps.append(complete_step)
        run_state.current_step_index += 1
    
    # 実行状態を更新
    self.runs[run_id] = run_state
    
    # イベントの発行
    log RunStepCompleted(run_id, step_index, StepType.MODEL_CALL, response_text)

@internal
def _process_tool_call(run_id: bytes32, step_index: uint256):
    """
    @notice ツール呼び出しのステップを処理する
    @param run_id 実行ID
    @param step_index ステップインデックス
    """
    # 実行状態の取得
    run_state: RunState = self.runs[run_id]
    current_step: ExecutionStep = run_state.steps[step_index]
    
    # 前のステップの取得（モデル呼び出し）
    previous_step: ExecutionStep = run_state.steps[step_index - 1]
    
    # ツールアドレスの取得
    tool_address: address = self.tool_registry.get_tool_address(current_step.tool_id)
    tool: ToolInterface.ExecutableToolInterface = ToolInterface.ExecutableToolInterface(tool_address)
    
    # ツール引数の取得
    tool_args: String[512] = self.model.get_tool_arguments(previous_step.response_id, tool.name())
    
    # ツール実行IDをチェック
    if current_step.tool_execution_id == empty(bytes32):
        # ツールをまだ実行していない場合は実行
        execution_id: bytes32 = tool.execute(tool_args)
        current_step.tool_execution_id = execution_id
        run_state.steps[step_index] = current_step
        self.runs[run_id] = run_state
        return
    
    # ツール実行の完了をチェック
    if not tool.is_execution_complete(current_step.tool_execution_id):
        return
    
    # ツール実行結果の取得
    result: String[1024] = tool.get_result(current_step.tool_execution_id)
    
    # 結果を保存
    current_step.output = result
    current_step.completed = True
    run_state.steps[step_index] = current_step
    
    # ツール使用動作に基づいて次のステップを決定
    if self.config.tool_use_behavior == AgentInterface.ToolUseBehavior.STOP_ON_FIRST_TOOL:
        # 最初のツール呼び出しで停止
        run_state.final_output = result
        
        # 完了ステップを追加
        complete_step: ExecutionStep = ExecutionStep({
            step_type: StepType.COMPLETE,
            response_id: empty(bytes32),
            tool_id: empty(bytes32),
            tool_execution_id: empty(bytes32),
            completed: False,
            output: ""
        })
        
        run_state.steps.append(complete_step)
        run_state.current_step_index += 1
    else:
        # デフォルト: ツール結果を含めて再度モデルを呼び出す
        tool_result_prompt: String[1024] = concat(
            "Previous output: ",
            previous_step.output,
            "\n\nTool result: ",
            result
        )
        
        # 新しいモデル呼び出しステップを追加
        model_step: ExecutionStep = ExecutionStep({
            step_type: StepType.MODEL_CALL,
            response_id: empty(bytes32),
            tool_id: empty(bytes32),
            tool_execution_id: empty(bytes32),
            completed: False,
            output: ""
        })
        
        run_state.steps.append(model_step)
        run_state.current_step_index += 1
        
        # AIモデルへの呼び出しを実行
        response_id: bytes32 = self.model.get_response(
            self.config.instructions,
            tool_result_prompt,
            ModelInterface.ModelTracing.ENABLED
        )
        
        # 応答IDを保存
        run_state.steps[run_state.current_step_index].response_id = response_id
    
    # 実行状態を更新
    self.runs[run_id] = run_state
    
    # イベントの発行
    log RunStepCompleted(run_id, step_index, StepType.TOOL_CALL, result)

@internal
def _prepare_next_step(run_id: bytes32):
    """
    @notice 次のステップを準備する
    @param run_id 実行ID
    """
    # 実行状態の取得
    run_state: RunState = self.runs[run_id]
    
    # 次のステップが存在する場合
    if run_state.current_step_index + 1 < len(run_state.steps):
        run_state.current_step_index += 1
        self.runs[run_id] = run_state

@external
@view
def get_result(run_id: bytes32) -> String[1024]:
    """
    @notice 実行結果を取得する
    @param run_id 実行ID
    @return 実行結果のテキスト
    """
    assert run_id in self.run_ids, "Run not found"
    return self.runs[run_id].final_output

@external
@view
def is_run_complete(run_id: bytes32) -> bool:
    """
    @notice 実行が完了したかどうかをチェックする
    @param run_id 実行ID
    @return 実行が完了した場合はTrue
    """
    assert run_id in self.run_ids, "Run not found"
    return self.runs[run_id].completed