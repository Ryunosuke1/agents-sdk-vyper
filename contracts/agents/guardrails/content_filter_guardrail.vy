# SPDX-License-Identifier: MIT
# @version ^0.3.3

# ContentFilterGuardrail - 有害コンテンツや不適切な言語を検出するためのガードレール

import contracts.agents.guardrails.interface as GuardrailInterface

interface OpenAIConnectorInterface:
    def requestOpenAICompletion(prompt: String[1024]) -> bytes32: nonpayable
    def getResponse(requestId: bytes32) -> (bool, String[1024]): view

# 禁止カテゴリの列挙型
enum ContentCategory:
    # HATE: ヘイトスピーチ
    HATE
    # VIOLENCE: 暴力的なコンテンツ
    VIOLENCE
    # SEXUAL: 性的なコンテンツ
    SEXUAL
    # HARASSMENT: ハラスメント
    HARASSMENT
    # SELF_HARM: 自傷行為
    SELF_HARM
    # MISINFORMATION: 誤情報
    MISINFORMATION

# フィルタリング結果の構造体
struct FilterResult:
    # フィルタリングの総合スコア (0-1000 = 0.0-1.0)
    overall_score: uint256
    # カテゴリごとのスコア (0-1000 = 0.0-1.0)
    category_scores: HashMap[ContentCategory, uint256]
    # フラグが立てられたカテゴリの数
    flagged_categories: uint256
    # 検出の理由説明
    reason: String[256]

# コントラクト変数
owner: public(address)
guardrail_name: public(String[64])
guardrail_description: public(String[256])
guardrail_type: public(GuardrailInterface.GuardrailType)
category_thresholds: public(HashMap[ContentCategory, uint256])
ai_connector: public(OpenAIConnectorInterface)

# 検証結果の追跡
validation_results: public(HashMap[bytes32, GuardrailInterface.GuardrailValidationInfo])
validation_ids: public(DynArray[bytes32, 100])
validation_completed: public(HashMap[bytes32, bool])
filter_results: public(HashMap[bytes32, FilterResult])
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
    overallScore: uint256
    flaggedCategories: uint256
    reason: String[256]

@external
def __init__(
    _name: String[64],
    _description: String[256],
    _type: GuardrailInterface.GuardrailType,
    _ai_connector_address: address
):
    """
    @notice コンテンツフィルタガードレールコントラクトの初期化
    @param _name ガードレールの名前
    @param _description ガードレールの説明
    @param _type ガードレールのタイプ
    @param _ai_connector_address AI APIコネクタのアドレス
    """
    self.owner = msg.sender
    self.guardrail_name = _name
    self.guardrail_description = _description
    self.guardrail_type = _type
    self.ai_connector = OpenAIConnectorInterface(_ai_connector_address)
    self.validation_count = 0
    
    # デフォルトのカテゴリしきい値を設定
    # すべてのカテゴリでデフォルト70%のしきい値
    self.category_thresholds[ContentCategory.HATE] = 700
    self.category_thresholds[ContentCategory.VIOLENCE] = 700
    self.category_thresholds[ContentCategory.SEXUAL] = 700
    self.category_thresholds[ContentCategory.HARASSMENT] = 700
    self.category_thresholds[ContentCategory.SELF_HARM] = 700
    self.category_thresholds[ContentCategory.MISINFORMATION] = 700
    
    # デフォルトの検証プロンプトテンプレート
    self.validation_prompt_template = """
    You are a content moderation system. Analyze the following text for harmful content in these categories:
    - HATE: Hate speech, discrimination, or prejudice
    - VIOLENCE: Violent content or threats
    - SEXUAL: Explicit sexual content
    - HARASSMENT: Bullying or harassment
    - SELF_HARM: Content promoting self-harm
    - MISINFORMATION: False or misleading information
    
    For each category, provide a score from The given text:
    """

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
def set_category_threshold(category: ContentCategory, threshold: uint256):
    """
    @notice カテゴリのしきい値を設定する
    @param category コンテンツカテゴリ
    @param threshold しきい値 (0-1000 = 0.0-1.0)
    """
    assert msg.sender == self.owner, "Only owner can set thresholds"
    assert threshold <= 1000, "Threshold must be between 0 and 1000"
    
    self.category_thresholds[category] = threshold

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
    prompt: String[1024] = concat(
        self.validation_prompt_template,
        "\n\nText to analyze: ",
        input_text,
        "\n\nRespond with a JSON containing overall_score, category_scores for each category, and reason."
    )
    
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
    
    # フィルタ結果の初期化
    filter_result: FilterResult = FilterResult({
        overall_score: 0,
        category_scores: empty(HashMap[ContentCategory, uint256]),
        flagged_categories: 0,
        reason: ""
    })
    
    # 検証情報の保存
    self.validation_results[validation_id] = validation_info
    self.filter_results[validation_id] = filter_result
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
    prompt: String[1024] = concat(
        self.validation_prompt_template,
        "\n\nText to analyze: ",
        output_text,
        "\n\nOriginal input context: ",
        input_context,
        "\n\nRespond with a JSON containing overall_score, category_scores for each category, and reason."
    )
    
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
    
    # フィルタ結果の初期化
    filter_result: FilterResult = FilterResult({
        overall_score: 0,
        category_scores: empty(HashMap[ContentCategory, uint256]),
        flagged_categories: 0,
        reason: ""
    })
    
    # 検証情報の保存
    self.validation_results[validation_id] = validation_info
    self.filter_results[validation_id] = filter_result
    self.validation_ids.append(validation_id)
    self.validation_completed[validation_id] = False
    
    # イベントの発行
    log ValidationStarted(validation_id, self.guardrail_type)
    
    return validation_id

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
    
    # 仮の解析結果
    overall_score: uint256 = 300  # 例: 0.3 (30%)
    reason: String[256] = "Content seems mostly acceptable with minor issues"
    
    # カテゴリスコアを初期化（簡略化のため仮の値）
    hate_score: uint256 = 200       # HATE: 20%
    violence_score: uint256 = 100   # VIOLENCE: 10%
    sexual_score: uint256 = 150     # SEXUAL: 15%
    harassment_score: uint256 = 250  # HARASSMENT: 25%
    self_harm_score: uint256 = 50   # SELF_HARM: 5%
    misinfo_score: uint256 = 300    # MISINFORMATION: 30%
    
    # フィルタ結果を保存
    filter_result: FilterResult = self.filter_results[validation_id]
    filter_result.overall_score = overall_score
    filter_result.category_scores[ContentCategory.HATE] = hate_score
    filter_result.category_scores[ContentCategory.VIOLENCE] = violence_score
    filter_result.category_scores[ContentCategory.SEXUAL] = sexual_score
    filter_result.category_scores[ContentCategory.HARASSMENT] = harassment_score
    filter_result.category_scores[ContentCategory.SELF_HARM] = self_harm_score
    filter_result.category_scores[ContentCategory.MISINFORMATION] = misinfo_score
    filter_result.reason = reason
    
    # フラグが立てられたカテゴリを数える
    flagged_count: uint256 = 0
    if hate_score >= self.category_thresholds[ContentCategory.HATE]:
        flagged_count += 1
    if violence_score >= self.category_thresholds[ContentCategory.VIOLENCE]:
        flagged_count += 1
    if sexual_score >= self.category_thresholds[ContentCategory.SEXUAL]:
        flagged_count += 1
    if harassment_score >= self.category_thresholds[ContentCategory.HARASSMENT]:
        flagged_count += 1
    if self_harm_score >= self.category_thresholds[ContentCategory.SELF_HARM]:
        flagged_count += 1
    if misinfo_score >= self.category_thresholds[ContentCategory.MISINFORMATION]:
        flagged_count += 1
    
    filter_result.flagged_categories = flagged_count
    
    # 結果の判定
    result: GuardrailInterface.GuardrailResult
    if flagged_count == 0:
        result = GuardrailInterface.GuardrailResult.PASS
    else:
        result = GuardrailInterface.GuardrailResult.FAIL
    
    # 検証結果の更新
    validation_info: GuardrailInterface.GuardrailValidationInfo = self.validation_results[validation_id]
    validation_info.result = result
    validation_info.score = overall_score
    validation_info.reason = reason
    
    self.validation_results[validation_id] = validation_info
    self.filter_results[validation_id] = filter_result
    self.validation_completed[validation_id] = True
    
    # イベントの発行
    log ValidationCompleted(validation_id, result, overall_score, flagged_count, reason)

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
def get_filter_result(validation_id: bytes32) -> FilterResult:
    """
    @notice フィルタリング結果の詳細を取得する
    @param validation_id 検証ID
    @return フィルタリング結果の詳細
    """
    assert validation_id in self.validation_ids, "Validation not found"
    return self.filter_results[validation_id]

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

@external
@view
def get_category_score(validation_id: bytes32, category: ContentCategory) -> uint256:
    """
    @notice 特定のカテゴリのスコアを取得する
    @param validation_id 検証ID
    @param category カテゴリ
    @return カテゴリのスコア
    """
    assert validation_id in self.validation_ids, "Validation not found"
    assert self.validation_completed[validation_id], "Validation not complete"
    
    return self.filter_results[validation_id].category_scores[category]