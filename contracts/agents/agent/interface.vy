# SPDX-License-Identifier: MIT
# @version ^0.3.3

# AgentState - エージェントの状態を表す列挙型
enum AgentState:
    # IDLE: アイドル状態（準備完了）
    IDLE
    # PROCESSING: 処理中
    PROCESSING
    # WAITING_FOR_TOOL: ツール実行の結果を待機中
    WAITING_FOR_TOOL
    # COMPLETED: 処理完了
    COMPLETED
    # ERROR: エラー発生
    ERROR

# ToolUseBehavior - ツール使用のふるまいを表す列挙型
enum ToolUseBehavior:
    # RUN_LLM_AGAIN: ツール実行後にLLMを再度実行
    RUN_LLM_AGAIN
    # STOP_ON_FIRST_TOOL: 最初のツール呼び出しで停止
    STOP_ON_FIRST_TOOL

# AgentInterface - エージェントの基本インターフェース
interface AgentInterface:
    # エージェントの名前を取得
    # @return エージェント名
    def name() -> String[64]: view
    
    # エージェントの指示を取得
    # @return エージェントへの指示
    def instructions() -> String[1024]: view
    
    # エージェントの現在の状態を取得
    # @return エージェントの状態
    def state() -> AgentState: view
    
    # エージェントのツール使用ふるまいを取得
    # @return ツール使用のふるまい
    def tool_use_behavior() -> ToolUseBehavior: view
    
    # 登録されているツールの数を取得
    # @return ツールの数
    def get_tool_count() -> uint256: view
    
    # 指定インデックスのツールIDを取得
    # @param index ツールインデックス
    # @return ツールID
    def get_tool_id(index: uint256) -> address: view
    
    # エージェントを実行する
    # @param input ユーザー入力
    # @return 実行ID
    def run(input: String[1024]) -> bytes32: nonpayable
    
    # 実行結果を取得する
    # @param run_id 実行ID
    # @return 実行結果のテキスト
    def get_result(run_id: bytes32) -> String[1024]: view
    
    # 実行が完了したかどうかをチェックする
    # @param run_id 実行ID
    # @return 実行が完了した場合はTrue
    def is_run_complete(run_id: bytes32) -> bool: view