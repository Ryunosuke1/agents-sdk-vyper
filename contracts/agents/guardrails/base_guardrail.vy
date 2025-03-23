# SPDX-License-Identifier: MIT
# @version ^0.3.3

# BaseGuardrail - すべてのガードレール実装の基本クラス

import contracts.agents.guardrails.interface as GuardrailInterface
import contracts.agents.models.interface as ModelInterface

interface OpenAIConnectorInterface:
    def requestOpenAICompletion(prompt: String[1024]) -> bytes32: nonpayable
    def getResponse(requestId: bytes32) -> (bool, String[1024]): view

# コントラクト変数
owner: public(address)
guardrail_name: public(String[64])
guardrail_description: public(String[256])
guardrail_type: public(GuardrailInterface.GuardrailType)
threshold: public(uint256)  # 検証通過しきい値（0-1000 = 0.0-1.0）
ai_connector: public(OpenAIConnectorInterface)

# 検証結果の追跡
validation_results: public(HashMap[bytes32, GuardrailInterface.GuardrailValidationInfo])
validation_ids: public(DynArray[bytes32, 100])
validation_completed: public(HashMap[bytes32, bool])
validation_count: public(uint256)

# 検証プロンプトのテンプレート
validation_prompt_template: public(String[512])

# イベント
event ValidationStarted:
    validationId: bytes32
    guardRailType: GuardrailInterface.GuardrailType

event ValidationCompleted:
    validationId: bytes32
    result: GuardrailInterface.GuardrailResult
    score: uint256
    reason: String[256]

@external
def __init__(
    _name: String[64],
    _description: String[256],
    _type: GuardrailInterface.GuardrailType,
    _threshold: uint256,
    _ai_connector_address: address,
    _prompt_template: String[512]
):
    """
    @notice ガードレールコントラクトの初期化
    @param _name ガードレールの名前
    @param _description ガードレールの説明
    @param _type ガードレールのタイプ
    @param _threshold 検証通過しきい値（0-1000 = 0.0-1.0）
    @param _ai_connector_address AI APIコネクタのアドレス
    @param _prompt_template 検証プロンプトのテンプレート
    """
    self.owner = msg.sender
    self.guardrail_name = _name
    self.guardrail_description = _description
    self.guardrail_type = _type
    self.threshold = _threshold
    self.ai_connector = OpenAIConnectorInterface(_ai_connector_address)
    self.validation_prompt_template = _prompt_template
    self.validation_count = 0

@external
@view
def name() -> String[64]:
    """
    @notice ガードレールの名前を取得
    @return ガードレールの名前
    """
    return self.guardrail_name

@external
@view
def guardrail_type() -> GuardrailInterface.GuardrailType:
    """
    @notice ガードレールのタイプを取得
    @return ガードレールのタイプ
    """
    return self.guardrail_type

@external
@view
def description() -> String[256]:
    """
    @notice ガードレールの説明を取得
    @return ガードレールの説明
    """
    return self.guardrail_description

@external
def validate_input(input_text: String[1024]) -> bytes32:
    """
    @notice 入力テキストを検証する
    @param input_text 検証する入力テキスト
    @return 検証ID
    """
    assert self.guardrail_type == GuardrailInterface.GuardrailType.INPUT, "Not an input guardrail"
    
    # 検証IDの生成
    validation_id: bytes32 = keccak256(concat(
        convert(block.timestamp, bytes32),
        convert(self.validation_count, bytes32),
        convert(msg.sender, bytes32)
    ))
    
    # 検証カウントの増加
    self.validation_count += 1
    
    # プロンプトの作成
    prompt: String[1024] = self._create_validation_prompt(input_text, "")
    
    # AI APIリクエストを送信
    request_id: bytes32 = self.ai_connector.requestOpenAICompletion(prompt)
    
    # 仮の検証結果情報を作成
    validation_info: GuardrailInterface.GuardrailValidationInfo = GuardrailInterface.GuardrailValidationInfo({
        guardrail_id: validation_id,
        name: self.guardrail_name,
        result: GuardrailInterface.GuardrailResult.PASS,  # デフォルト値、後で更新
        score: 0,  # デフォルト値、後で更新
        reason: "",  # デフォルト値、後で更新
        timestamp: block.timestamp
    })
    
    # 検証情報の保存
    self.validation_results[validation_id] = validation_info
    self.validation_ids.append(validation_id)
    self.validation_completed[validation_id] = False
    
    # イベントの発行
    log ValidationStarted(validation_id, self.guardrail_type)
    
    return validation_id

@external
def validate_output(output_text: String[1024], input_context: String[1024]) -> bytes32:
    """
    @notice 出力テキストを検証する
    @param output_text 検証する出力テキスト
    @param input_context 関連する入力コンテキスト
    @return 検証ID
    """
    assert self.guardrail_type == GuardrailInterface.GuardrailType.OUTPUT, "Not an output guardrail"
    
    # 検証IDの生成
    validation_id: bytes32 = keccak256(concat(
        convert(block.timestamp, bytes32),
        convert(self.validation_count, bytes32),
        convert(msg.sender, bytes32)
    ))
    
    # 検証カウントの増加
    self.validation_count += 1
    
    # プロンプトの作成
    prompt: String[1024] = self._create_validation_prompt(output_text, input_context)
    
    # AI APIリクエストを送信
    request_id: bytes32 = self.ai_connector.requestOpenAICompletion(prompt)
    
    # 仮の検証結果情報を作成
    validation_info: GuardrailInterface.GuardrailValidationInfo = GuardrailInterface.GuardrailValidationInfo({
        guardrail_id: validation_id,
        name: self.guardrail_name,
        result: GuardrailInterface.GuardrailResult.PASS,  # デフォルト値、後で更新
        score: 0,  # デフォルト値、後で更新
        reason: "",  # デフォルト値、後で更新
        timestamp: block.timestamp
    })
    
    # 検証情報の保存
    self.validation_results[validation_id] = validation_info
    self.validation_ids.append(validation_id)
    self.validation_completed[validation_id] = False
    
    # イベントの発行
    log ValidationStarted(validation_id, self.guardrail_type)
    
    return validation_id

@internal
def _create_validation_prompt(text: String[1024], context: String[1024]) -> String[1024]:
    """
    @notice 検証プロンプトを作成する
    @param text 検証するテキスト
    @param context 追加コンテキスト
    @return 検証プロンプト
    """
    # プロンプトの作成（テンプレートに変数を埋め込み）
    if self.guardrail_type == GuardrailInterface.GuardrailType.INPUT:
        prompt: String[1024] = concat(
            self.validation_prompt_template,
            "\nInput to validate: ",
            text,
            "\nRespond with a JSON containing score (0-100) and reason."
        )
    else:  # OUTPUT type
        prompt: String[1024] = concat(
            self.validation_prompt_template,
            "\nOutput to validate: ",
            text,
            "\nOriginal input context: ",
            context,
            "\nRespond with a JSON containing score (0-100) and reason."
        )
    
    return prompt

@external
def check_and_update_validation(validation_id: bytes32):
    """
    @notice 検証結果の確認と更新
    @param validation_id 検証ID
    """
    # 検証IDの存在確認
    assert validation_id in self.validation_ids, "Validation not found"
    
    # すでに完了している場合はスキップ
    if self.validation_completed[validation_id]:
        return
    
    # AI APIからの応答を確認
    is_complete: bool = False
    response: String[1024] = ""
    
    # 応答を取得
    is_complete, response = self.ai_connector.getResponse(validation_id)
    
    if not is_complete:
        return
    
    # 応答の解析（実際の実装では、JSONのパースが必要）
    # 簡略化のため、仮のスコアと理由を設定
    # 注: 実際の実装では、JSONレスポンスを解析して適切な値を抽出する必要がある
    score: uint256 = 800  # 例: 0.8 (80%)
    reason: String[256] = "Example validation result"
    
    # 結果の判定
    result: GuardrailInterface.GuardrailResult
    if score >= self.threshold:
        result = GuardrailInterface.GuardrailResult.PASS
    else:
        result = GuardrailInterface.GuardrailResult.FAIL
    
    # 検証結果の更新
    validation_info: GuardrailInterface.GuardrailValidationInfo = self.validation_results[validation_id]
    validation_info.result = result
    validation_info.score = score
    validation_info.reason = reason
    
    self.validation_results[validation_id] = validation_info
    self.validation_completed[validation_id] = True
    
    # イベントの発行
    log ValidationCompleted(validation_id, result, score, reason)

@external
@view
def get_validation_result(validation_id: bytes32) -> GuardrailInterface.GuardrailValidationInfo:
    """
    @notice 検証結果を取得する
    @param validation_id 検証ID
    @return 検証結果の情報
    """
    assert validation_id in self.validation_ids, "Validation not found"
    return self.validation_results[validation_id]

@external
@view
def is_validation_complete(validation_id: bytes32) -> bool:
    """
    @notice 検証が完了したかどうかを確認する
    @param validation_id 検証ID
    @return 検証が完了した場合はTrue
    """
    assert validation_id in self.validation_ids, "Validation not found"
    return self.validation_completed[validation_id]