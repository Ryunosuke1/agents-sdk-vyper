# SPDX-License-Identifier: MIT
# @version ^0.3.3

# ToolType - サポートされるツールタイプを表す列挙型
enum ToolType:
    # FUNCTION: 関数ツール（標準的なスマートコントラクト関数を呼び出す）
    FUNCTION
    # EXTERNAL_API: 外部API呼び出し（Chainlinkを使用）
    EXTERNAL_API
    # AI_MODEL: 別のAIモデルを呼び出す
    AI_MODEL

# ToolInterface - 基本的なツールインターフェース
interface ToolInterface:
    # ツールの名前を取得
    # @return ツールの名前
    def name() -> String[64]: view
    
    # ツールの説明を取得
    # @return ツールの説明
    def description() -> String[256]: view
    
    # ツールのタイプを取得
    # @return ツールのタイプ
    def tool_type() -> ToolType: view
    
    # ツールのパラメータスキーマを取得（JSON形式）
    # @return パラメータスキーマの文字列表現
    def params_schema() -> String[512]: view

# ExecutableToolInterface - 実行可能なツールのインターフェース
interface ExecutableToolInterface:
    # ツールを実行する
    # @param args ツール引数（JSON形式）
    # @return 実行の結果ID
    def execute(args: String[512]) -> bytes32: nonpayable
    
    # 実行結果を取得する
    # @param execution_id 実行ID
    # @return 実行結果（JSON形式または文字列）
    def get_result(execution_id: bytes32) -> String[1024]: view
    
    # 実行が完了したかどうかをチェックする
    # @param execution_id 実行ID
    # @return 実行が完了した場合はTrue
    def is_execution_complete(execution_id: bytes32) -> bool: view