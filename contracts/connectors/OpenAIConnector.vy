# SPDX-License-Identifier: MIT
# @version ^0.3.3

# OpenAI API コネクタコントラクト
# このコントラクトはChainlinkを使用してスマートコントラクトからOpenAI APIに接続します

from vyper.interfaces import ERC20

interface LinkTokenInterface:
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def transferAndCall(_to: address, _value: uint256, _data: Bytes[1024]) -> bool: nonpayable

interface ChainlinkOracleInterface:
    def fulfillOracleRequest(requestId: bytes32, payment: uint256, callbackAddress: address, callbackFunctionId: bytes4, expiration: uint256, data: bytes32) -> bool: nonpayable

# リクエスト状態を追跡するための構造体
struct RequestStatus:
    isOpen: bool
    prompt: String[1024]
    response: String[1024]
    callerAddress: address
    timestamp: uint256

# ChainlinkコンポーネントのAPIコール情報
struct ChainlinkInfo:
    token: address      # LINKトークンのアドレス
    oracle: address     # Chainlinkオラクルのアドレス
    jobId: bytes32      # OpenAI APIへの接続用ジョブID
    fee: uint256        # オラクルリクエスト手数料（LINK単位）

# コントラクト変数
owner: public(address)
chainlinkInfo: public(ChainlinkInfo)
requests: public(HashMap[bytes32, RequestStatus])  # リクエストID => リクエスト情報
userRequests: public(HashMap[address, DynArray[bytes32, 100]])  # ユーザーアドレス => リクエストIDのリスト
requestIds: public(DynArray[bytes32, 1000])  # 全てのリクエストID

# イベント
event RequestSent:
    requestId: bytes32
    prompt: String[1024]
    caller: address

event ResponseReceived:
    requestId: bytes32
    response: String[1024]

@external
def __init__(_linkToken: address, _oracle: address, _jobId: bytes32, _fee: uint256):
    """
    @notice コントラクトの初期化
    @param _linkToken LINKトークンのアドレス
    @param _oracle Chainlinkオラクルのアドレス
    @param _jobId OpenAI API接続用のChainlinkジョブID
    @param _fee オラクルリクエストの費用
    """
    self.owner = msg.sender
    self.chainlinkInfo = ChainlinkInfo({
        token: _linkToken,
        oracle: _oracle,
        jobId: _jobId,
        fee: _fee
    })

@external
def requestOpenAICompletion(prompt: String[1024]) -> bytes32:
    """
    @notice OpenAI APIにプロンプトを送信し、完了を要求する
    @param prompt APIに送信する入力プロンプト
    @return requestId 生成されたリクエストID
    """
    # LINK残高の確認
    link_token: LinkTokenInterface = LinkTokenInterface(self.chainlinkInfo.token)
    assert link_token.balanceOf(self) >= self.chainlinkInfo.fee, "Not enough LINK tokens"
    
    # 一意のリクエストIDを生成
    requestId: bytes32 = keccak256(concat(
        convert(block.timestamp, bytes32),
        convert(len(self.requestIds), bytes32),
        convert(msg.sender, bytes32)
    ))
    
    # リクエストの保存
    self.requests[requestId] = RequestStatus({
        isOpen: True,
        prompt: prompt,
        response: "",
        callerAddress: msg.sender,
        timestamp: block.timestamp
    })
    
    # リクエストIDをインデックスに追加
    self.requestIds.append(requestId)
    self.userRequests[msg.sender].append(requestId)
    
    # Chainlinkオラクルにリクエストを送信
    # 実際の実装では、このリクエストを適切にエンコードして送信する必要がある
    # ここでは簡略化のため、詳細な実装は省略
    
    # イベントの発行
    log RequestSent(requestId, prompt, msg.sender)
    
    return requestId

@external
def fulfillOpenAIRequest(requestId: bytes32, response: String[1024]):
    """
    @notice Chainlinkノードからのコールバック関数、OpenAI APIレスポンスを受け取る
    @param requestId 完了するリクエストのID
    @param response APIからのレスポンス
    """
    # コールバックの呼び出し元チェック - 実際にはもっと厳密なチェックが必要
    assert msg.sender == self.chainlinkInfo.oracle, "Only oracle can fulfill"
    
    # リクエストが存在し、オープンであることを確認
    assert self.requests[requestId].isOpen, "Request not found or already fulfilled"
    
    # レスポンスを保存
    self.requests[requestId].response = response
    self.requests[requestId].isOpen = False
    
    # イベントの発行
    log ResponseReceived(requestId, response)

@external
@view
def getResponse(requestId: bytes32) -> (bool, String[1024]):
    """
    @notice リクエストIDに関連付けられたレスポンスを取得
    @param requestId 確認するリクエストのID
    @return 完了フラグとレスポンス
    """
    status: RequestStatus = self.requests[requestId]
    return (not status.isOpen, status.response)

@external
@view
def getUserRequests(user: address) -> DynArray[bytes32, 100]:
    """
    @notice 特定のユーザーのリクエストIDをすべて取得
    @param user 確認するユーザーのアドレス
    @return ユーザーのリクエストID配列
    """
    return self.userRequests[user]

@external
def withdrawLink():
    """
    @notice コントラクトに残っているLINKを引き出す（緊急時用）
    """
    assert msg.sender == self.owner, "Only owner can withdraw"
    
    link_token: LinkTokenInterface = LinkTokenInterface(self.chainlinkInfo.token)
    balance: uint256 = link_token.balanceOf(self)
    assert link_token.transfer(self.owner, balance), "Transfer failed"