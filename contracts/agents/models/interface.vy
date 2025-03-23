# SPDX-License-Identifier: MIT
# @version ^0.3.3

# ModelTracing - モデルトレーシングの状態を表す列挙型
enum ModelTracing:
    # DISABLED: トレーシングが完全に無効
    DISABLED
    # ENABLED: トレーシングが有効で、すべてのデータを含む
    ENABLED
    # ENABLED_WITHOUT_DATA: トレーシングは有効だが、入力と出力は含まれない
    ENABLED_WITHOUT_DATA

# ModelInterface - AIモデルインターフェース
# このインターフェースは、異なるAIモデル実装のための共通の基底インターフェースを定義します
interface ModelInterface:
    # AIモデルに対してプロンプトを送信し、レスポンスを取得する
    # @param system_instructions システムプロンプト（指示）
    # @param input ユーザー入力またはコンテキスト
    # @param tracing トレーシングモード
    # @return レスポンスID
    def get_response(
        system_instructions: String[1024],
        input: String[1024],
        tracing: ModelTracing
    ) -> bytes32: nonpayable

    # 特定のレスポンスIDに関連付けられた出力テキストを取得する
    # @param response_id 取得するレスポンスのID
    # @return レスポンスのテキスト出力
    def get_response_text(response_id: bytes32) -> String[1024]: view

    # レスポンスが特定のツールを呼び出すかどうかをチェックする
    # @param response_id チェックするレスポンスのID
    # @param tool_name チェックするツール名
    # @return ツールが呼び出される場合はTrue
    def calls_tool(response_id: bytes32, tool_name: String[64]) -> bool: view

    # 特定のレスポンスIDに関連付けられたツール引数を取得する
    # @param response_id 取得するレスポンスのID
    # @param tool_name 取得するツール名
    # @return ツール引数（JSON形式）
    def get_tool_arguments(response_id: bytes32, tool_name: String[64]) -> String[512]: view
