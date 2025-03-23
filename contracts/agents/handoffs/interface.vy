# SPDX-License-Identifier: MIT
# @version ^0.3.3

# Handoff - エージェント間のハンドオフを管理するためのインターフェースと構造体定義

# ハンドオフステータスを表す列挙型
enum HandoffStatus:
    # NONE: ハンドオフなし
    NONE 
    # PENDING: ハンドオフ待機中
    PENDING
    # COMPLETED: ハンドオフ完了
    COMPLETED
    # REJECTED: ハンドオフ拒否
    REJECTED

# ハンドオフ情報を保持するための構造体
struct HandoffInfo:
    # 送信元エージェントのアドレス
    source_agent: address
    # 送信先エージェントのアドレス
    target_agent: address
    # ハンドオフの入力データ
    input_data: String[1024]
    # ハンドオフの状態
    status: HandoffStatus
    # ハンドオフの結果ID（ターゲットエージェントの実行ID）
    result_run_id: bytes32
    # タイムスタンプ
    timestamp: uint256

# HandoffInterface - ハンドオフ機能を提供するインターフェース
interface HandoffInterface:
    # ハンドオフを実行する
    # @param target_agent_address ハンドオフ先のエージェントアドレス
    # @param input_data ハンドオフ時の入力データ
    # @return ハンドオフID
    def handoff(target_agent_address: address, input_data: String[1024]) -> bytes32: nonpayable
    
    # ハンドオフの状態を取得する
    # @param handoff_id ハンドオフID
    # @return ハンドオフの状態
    def get_handoff_status(handoff_id: bytes32) -> HandoffStatus: view
    
    # ハンドオフの詳細情報を取得する
    # @param handoff_id ハンドオフID
    # @return ハンドオフ情報
    def get_handoff_info(handoff_id: bytes32) -> HandoffInfo: view
    
    # ハンドオフの結果を取得する
    # @param handoff_id ハンドオフID
    # @return ハンドオフ先エージェントからの結果
    def get_handoff_result(handoff_id: bytes32) -> String[1024]: view