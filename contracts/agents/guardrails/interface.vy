# SPDX-License-Identifier: MIT
# @version ^0.3.3

# Guardrail - エージェントのインプットとアウトプットを検証するためのガードレール機能

# ガードレールのタイプ
enum GuardrailType:
    # INPUT: 入力ガードレール
    INPUT
    # OUTPUT: 出力ガードレール
    OUTPUT

# ガードレールの結果ステータス
enum GuardrailResult:
    # PASS: 検証通過
    PASS
    # FAIL: 検証失敗
    FAIL
    # ERROR: 検証中にエラー発生
    ERROR

# ガードレールの検証結果情報
struct GuardrailValidationInfo:
    # ガードレールID
    guardrail_id: bytes32
    # ガードレールの名前
    name: String[64]
    # 検証結果のステータス
    result: GuardrailResult
    # 検証のスコア（0-1000 = 0.0-1.0）
    score: uint256
    # 失敗時の理由
    reason: String[256]
    # タイムスタンプ
    timestamp: uint256

# ガードレールインターフェース - ガードレールの共通機能を定義
interface GuardrailInterface:
    # ガードレールの名前を取得
    # @return ガードレールの名前
    def name() -> String[64]: view
    
    # ガードレールのタイプを取得
    # @return ガードレールのタイプ
    def guardrail_type() -> GuardrailType: view
    
    # ガードレールの説明を取得
    # @return ガードレールの説明
    def description() -> String[256]: view
    
    # 入力テキストを検証する（入力ガードレール用）
    # @param input_text 検証する入力テキスト
    # @return 検証ID
    def validate_input(input_text: String[1024]) -> bytes32: nonpayable
    
    # 出力テキストを検証する（出力ガードレール用）
    # @param output_text 検証する出力テキスト
    # @param input_context 関連する入力コンテキスト（オプション）
    # @return 検証ID
    def validate_output(output_text: String[1024], input_context: String[1024]) -> bytes32: nonpayable
    
    # 検証結果を取得する
    # @param validation_id 検証ID
    # @return 検証結果の情報
    def get_validation_result(validation_id: bytes32) -> GuardrailValidationInfo: view
    
    # 検証が完了したかどうかを確認する
    # @param validation_id 検証ID
    # @return 検証が完了した場合はTrue
    def is_validation_complete(validation_id: bytes32) -> bool: view