# SPDX-License-Identifier: MIT
# @version ^0.3.3

# HandoffManager - エージェント間のハンドオフを管理するコントラクト

import contracts.agents.handoffs.interface as HandoffInterface
import contracts.agents.agent.interface as AgentInterface

# コントラクト変数
owner: public(address)
handoffs: public(HashMap[bytes32, HandoffInterface.HandoffInfo])
handoff_ids: public(DynArray[bytes32, 100])
agent_handoffs: public(HashMap[address, DynArray[bytes32, 50]])

# イベント
event HandoffCreated:
    handoffId: bytes32
    sourceAgent: address
    targetAgent: address
    inputData: String[1024]

event HandoffStatusChanged:
    handoffId: bytes32
    newStatus: HandoffInterface.HandoffStatus

@external
def __init__():
    """
    @notice ハンドオフマネージャーコントラクトの初期化
    """
    self.owner = msg.sender

@external
def handoff(target_agent_address: address, input_data: String[1024]) -> bytes32:
    """
    @notice ハンドオフを実行する
    @param target_agent_address ハンドオフ先のエージェントアドレス
    @param input_data ハンドオフ時の入力データ
    @return ハンドオフID
    """
    # 対象のエージェントが存在するか確認
    agent: AgentInterface.AgentInterface = AgentInterface.AgentInterface(target_agent_address)
    
    # ハンドオフIDの生成
    handoff_id: bytes32 = keccak256(concat(
        convert(block.timestamp, bytes32),
        convert(len(self.handoff_ids), bytes32),
        convert(msg.sender, bytes32),
        convert(target_agent_address, bytes32)
    ))
    
    # ハンドオフ情報の作成
    handoff_info: HandoffInterface.HandoffInfo = HandoffInterface.HandoffInfo({
        source_agent: msg.sender,
        target_agent: target_agent_address,
        input_data: input_data,
        status: HandoffInterface.HandoffStatus.PENDING,
        result_run_id: empty(bytes32),
        timestamp: block.timestamp
    })
    
    # ハンドオフの保存
    self.handoffs[handoff_id] = handoff_info
    self.handoff_ids.append(handoff_id)
    
    # エージェントのハンドオフリストに追加
    self.agent_handoffs[msg.sender].append(handoff_id)
    
    # イベントの発行
    log HandoffCreated(handoff_id, msg.sender, target_agent_address, input_data)
    
    # ターゲットエージェントでの実行を開始
    # 注: 実際にはメッセージ呼び出しだけでなく、別のトランザクションでの処理が必要かもしれません
    run_id: bytes32 = agent.run(input_data)
    
    # 実行IDを保存
    handoff_info.result_run_id = run_id
    self.handoffs[handoff_id] = handoff_info
    
    return handoff_id

@external
def update_handoff_status(handoff_id: bytes32, new_status: HandoffInterface.HandoffStatus):
    """
    @notice ハンドオフのステータスを更新する
    @param handoff_id ハンドオフID
    @param new_status 新しいステータス
    """
    # ハンドオフの存在確認
    assert handoff_id in self.handoff_ids, "Handoff not found"
    
    # 適切な権限チェック（ソースエージェント、ターゲットエージェント、またはオーナーのみ）
    handoff_info: HandoffInterface.HandoffInfo = self.handoffs[handoff_id]
    assert msg.sender == handoff_info.source_agent or msg.sender == handoff_info.target_agent or msg.sender == self.owner, "Unauthorized"
    
    # ステータスの更新
    handoff_info.status = new_status
    self.handoffs[handoff_id] = handoff_info
    
    # イベントの発行
    log HandoffStatusChanged(handoff_id, new_status)

@external
@view
def get_handoff_status(handoff_id: bytes32) -> HandoffInterface.HandoffStatus:
    """
    @notice ハンドオフの状態を取得する
    @param handoff_id ハンドオフID
    @return ハンドオフの状態
    """
    assert handoff_id in self.handoff_ids, "Handoff not found"
    return self.handoffs[handoff_id].status

@external
@view
def get_handoff_info(handoff_id: bytes32) -> HandoffInterface.HandoffInfo:
    """
    @notice ハンドオフの詳細情報を取得する
    @param handoff_id ハンドオフID
    @return ハンドオフ情報
    """
    assert handoff_id in self.handoff_ids, "Handoff not found"
    return self.handoffs[handoff_id]

@external
@view
def get_handoff_result(handoff_id: bytes32) -> String[1024]:
    """
    @notice ハンドオフの結果を取得する
    @param handoff_id ハンドオフID
    @return ハンドオフ先エージェントからの結果
    """
    assert handoff_id in self.handoff_ids, "Handoff not found"
    
    handoff_info: HandoffInterface.HandoffInfo = self.handoffs[handoff_id]
    
    # ハンドオフが完了している場合のみ結果を取得
    assert handoff_info.status == HandoffInterface.HandoffStatus.COMPLETED, "Handoff not completed"
    
    # ターゲットエージェントから結果を取得
    agent: AgentInterface.AgentInterface = AgentInterface.AgentInterface(handoff_info.target_agent)
    return agent.get_result(handoff_info.result_run_id)

@external
@view
def get_agent_handoffs(agent_address: address) -> DynArray[bytes32, 50]:
    """
    @notice 特定のエージェントのハンドオフリストを取得する
    @param agent_address エージェントのアドレス
    @return ハンドオフIDのリスト
    """
    return self.agent_handoffs[agent_address]