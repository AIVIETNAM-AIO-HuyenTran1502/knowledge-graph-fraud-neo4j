// ============================================================
// 03 — ĐÁNH GIÁ ĐỊNH LƯỢNG
// ------------------------------------------------------------
// Dựng ground truth ở cấp Account, confusion matrix và Precision/Recall/F1 cho từng phương pháp.
// Chạy trước: 02_inference_9CQ.cypher (cần có sẵn SuspectedMule, SHARES_IDENTITY_WITH, POSSIBLY_SAME_FRAUD_RING, communityId).
// Mỗi khối dán vào một ô lệnh riêng trong Neo4j Browser, theo đúng thứ tự.
// ============================================================

// ============================================================
// GIAI ĐOẠN 6 — ĐÁNH GIÁ ĐỊNH LƯỢNG (CHỈ DÙNG CYPHER THUẦN)
// Chạy TUẦN TỰ từng khối theo đúng thứ tự trong Neo4j Browser.
// Yêu cầu: đã chạy xong toàn bộ Giai đoạn 5 (SuspectedMule,
// SHARES_IDENTITY_WITH, POSSIBLY_SAME_FRAUD_RING, communityId đã có sẵn)
// ============================================================


// ============================================================
// BƯỚC 6.0 — XÁC ĐỊNH RÕ ĐƠN VỊ ĐÁNH GIÁ
// (không phải câu lệnh chạy, chỉ là ghi chú định hướng)
// - Đánh giá cấp Node (Account-level): SuspectedMule vs isFraud thật
// - Đánh giá cấp Cặp (Pair-level): POSSIBLY_SAME_FRAUD_RING vs
//   2 account có thực sự cùng liên quan 1 vụ fraud không
// ============================================================


// ============================================================
// BƯỚC 6.1 — XÂY DỰNG GROUND TRUTH Ở CẤP ĐỘ ACCOUNT
// ============================================================
MATCH (c:Client)
OPTIONAL MATCH (c)-[:PERFORMED|TO]-(t:Transaction)
WHERE t.isFraud = 1
WITH c, count(t) > 0 AS actuallyFraudRelated
SET c.groundTruthFraud = actuallyFraudRelated
RETURN count(CASE WHEN actuallyFraudRelated THEN 1 END) AS fraud_related_accounts,
       count(c) AS total_accounts;


// ============================================================
// BƯỚC 6.2 — CONFUSION MATRIX & PRECISION/RECALL/F1
// CHO LUẬT ĐƠN: SuspectedMule (CQ5, rule-based thuần)
// ============================================================
MATCH (c:Client)
WITH
  coalesce(c.groundTruthFraud, false) AS actual,
  c:SuspectedMule AS predicted
WITH
  sum(CASE WHEN actual AND predicted THEN 1 ELSE 0 END) AS TP,
  sum(CASE WHEN NOT actual AND predicted THEN 1 ELSE 0 END) AS FP,
  sum(CASE WHEN actual AND NOT predicted THEN 1 ELSE 0 END) AS FN,
  sum(CASE WHEN NOT actual AND NOT predicted THEN 1 ELSE 0 END) AS TN
RETURN 'Rule-based only (SuspectedMule)' AS method,
  TP, FP, FN, TN,
  CASE WHEN (TP + FP) = 0 THEN 0.0 ELSE toFloat(TP) / (TP + FP) END AS precision,
  CASE WHEN (TP + FN) = 0 THEN 0.0 ELSE toFloat(TP) / (TP + FN) END AS recall,
  CASE WHEN (2*TP + FP + FN) = 0 THEN 0.0 ELSE (2.0 * TP) / (2.0*TP + FP + FN) END AS f1_score;


// ============================================================
// BƯỚC 6.3 — CONFUSION MATRIX & PRECISION/RECALL/F1
// CHO PIPELINE ĐA TẦNG: SuspectedMule HOẶC tham gia
// POSSIBLY_SAME_FRAUD_RING (kết hợp Mule + Community + Similarity)
// ============================================================
MATCH (c:Client)
OPTIONAL MATCH (c)-[:POSSIBLY_SAME_FRAUD_RING]-()
WITH c, coalesce(c.groundTruthFraud, false) AS actual,
     (c:SuspectedMule OR count(*) > 0) AS predicted
WITH
  sum(CASE WHEN actual AND predicted THEN 1 ELSE 0 END) AS TP,
  sum(CASE WHEN NOT actual AND predicted THEN 1 ELSE 0 END) AS FP,
  sum(CASE WHEN actual AND NOT predicted THEN 1 ELSE 0 END) AS FN,
  sum(CASE WHEN NOT actual AND NOT predicted THEN 1 ELSE 0 END) AS TN
RETURN 'Multi-layer inference (Mule+Community+Similarity)' AS method,
  TP, FP, FN, TN,
  CASE WHEN (TP + FP) = 0 THEN 0.0 ELSE toFloat(TP) / (TP + FP) END AS precision,
  CASE WHEN (TP + FN) = 0 THEN 0.0 ELSE toFloat(TP) / (TP + FN) END AS recall,
  CASE WHEN (2*TP + FP + FN) = 0 THEN 0.0 ELSE (2.0 * TP) / (2.0*TP + FP + FN) END AS f1_score;


// ============================================================
// BƯỚC 6.4 — CONFUSION MATRIX RIÊNG CHO SHARES_IDENTITY_WITH
// (đánh giá độc lập luật suy diễn identity, cấp độ Node:
//  1 Client có tham gia ít nhất 1 quan hệ SHARES_IDENTITY_WITH không)
// ============================================================
MATCH (c:Client)
OPTIONAL MATCH (c)-[:SHARES_IDENTITY_WITH]-()
WITH c, coalesce(c.groundTruthFraud, false) AS actual, count(*) > 0 AS predicted
WITH
  sum(CASE WHEN actual AND predicted THEN 1 ELSE 0 END) AS TP,
  sum(CASE WHEN NOT actual AND predicted THEN 1 ELSE 0 END) AS FP,
  sum(CASE WHEN actual AND NOT predicted THEN 1 ELSE 0 END) AS FN,
  sum(CASE WHEN NOT actual AND NOT predicted THEN 1 ELSE 0 END) AS TN
RETURN 'Shared Identity only' AS method,
  TP, FP, FN, TN,
  CASE WHEN (TP + FP) = 0 THEN 0.0 ELSE toFloat(TP) / (TP + FP) END AS precision,
  CASE WHEN (TP + FN) = 0 THEN 0.0 ELSE toFloat(TP) / (TP + FN) END AS recall,
  CASE WHEN (2*TP + FP + FN) = 0 THEN 0.0 ELSE (2.0 * TP) / (2.0*TP + FP + FN) END AS f1_score;


// ============================================================
// BƯỚC 6.5 — ĐÁNH GIÁ CẤP ĐỘ CẶP (PAIR-LEVEL) CHO
// POSSIBLY_SAME_FRAUD_RING — trả lời trực tiếp CQ9
// Ground truth cặp: 2 Client có "actually cùng ring" nếu cả 2 đều
// từng xuất hiện trong giao dịch fraud VÀ có liên kết gián tiếp
// qua Transaction chung (đã tính ở CQ4) hoặc cùng liên quan 1 mule
// ============================================================

// 6.5a — Xây ground truth cấp cặp (đơn giản hoá: cả 2 đều fraud-related)
MATCH (a:Client)-[r:POSSIBLY_SAME_FRAUD_RING]->(b:Client)
WITH a, b, r,
     coalesce(a.groundTruthFraud, false) AS a_actual,
     coalesce(b.groundTruthFraud, false) AS b_actual
WITH
  sum(CASE WHEN a_actual AND b_actual THEN 1 ELSE 0 END) AS TP_pairs,
  sum(CASE WHEN NOT (a_actual AND b_actual) THEN 1 ELSE 0 END) AS FP_pairs,
  count(*) AS total_predicted_pairs
RETURN 'POSSIBLY_SAME_FRAUD_RING (pair-level)' AS method,
  TP_pairs, FP_pairs, total_predicted_pairs,
  CASE WHEN total_predicted_pairs = 0 THEN 0.0
       ELSE toFloat(TP_pairs) / total_predicted_pairs END AS precision_pairs;


// ============================================================
// BƯỚC 6.6 — BẢNG SO SÁNH TỔNG HỢP 3 PHƯƠNG PHÁP TRÊN CÙNG 1 KẾT QUẢ
// (gộp lại thành 1 bảng duy nhất để đưa thẳng vào báo cáo/slide)
// ============================================================
CALL (){
  MATCH (c:Client)
  WITH coalesce(c.groundTruthFraud, false) AS actual, c:SuspectedMule AS predicted
  WITH
    sum(CASE WHEN actual AND predicted THEN 1 ELSE 0 END) AS TP,
    sum(CASE WHEN NOT actual AND predicted THEN 1 ELSE 0 END) AS FP,
    sum(CASE WHEN actual AND NOT predicted THEN 1 ELSE 0 END) AS FN
  RETURN 'Rule-based only' AS method,
    CASE WHEN (TP+FP)=0 THEN 0.0 ELSE toFloat(TP)/(TP+FP) END AS precision,
    CASE WHEN (TP+FN)=0 THEN 0.0 ELSE toFloat(TP)/(TP+FN) END AS recall
}
RETURN method, precision, recall

UNION ALL

CALL (){
  MATCH (c:Client)
  OPTIONAL MATCH (c)-[:SHARES_IDENTITY_WITH]-()
  WITH c, coalesce(c.groundTruthFraud, false) AS actual, count(*) > 0 AS predicted
  WITH
    sum(CASE WHEN actual AND predicted THEN 1 ELSE 0 END) AS TP,
    sum(CASE WHEN NOT actual AND predicted THEN 1 ELSE 0 END) AS FP,
    sum(CASE WHEN actual AND NOT predicted THEN 1 ELSE 0 END) AS FN
  RETURN 'Shared Identity only' AS method,
    CASE WHEN (TP+FP)=0 THEN 0.0 ELSE toFloat(TP)/(TP+FP) END AS precision,
    CASE WHEN (TP+FN)=0 THEN 0.0 ELSE toFloat(TP)/(TP+FN) END AS recall
}
RETURN method, precision, recall

UNION ALL

CALL (){
  MATCH (c:Client)
  OPTIONAL MATCH (c)-[:POSSIBLY_SAME_FRAUD_RING]-()
  WITH c, coalesce(c.groundTruthFraud, false) AS actual,
       (c:SuspectedMule OR count(*) > 0) AS predicted
  WITH
    sum(CASE WHEN actual AND predicted THEN 1 ELSE 0 END) AS TP,
    sum(CASE WHEN NOT actual AND predicted THEN 1 ELSE 0 END) AS FP,
    sum(CASE WHEN actual AND NOT predicted THEN 1 ELSE 0 END) AS FN
  RETURN 'Multi-layer inference' AS method,
    CASE WHEN (TP+FP)=0 THEN 0.0 ELSE toFloat(TP)/(TP+FP) END AS precision,
    CASE WHEN (TP+FN)=0 THEN 0.0 ELSE toFloat(TP)/(TP+FN) END AS recall
}
RETURN method, precision, recall;


// ============================================================
// BƯỚC 6.7 — THỐNG KÊ BỔ SUNG: PHÂN BỐ SỐ LƯỢNG THEO TỪNG NHÃN
// (giúp giải thích tại sao Precision/Recall ra như vậy trong báo cáo)
// ============================================================
MATCH (c:Client)
RETURN
  count(c) AS total_client,
  count(CASE WHEN c.groundTruthFraud = true THEN 1 END) AS total_actual_fraud,
  count(CASE WHEN c:SuspectedMule THEN 1 END) AS total_predicted_mule,
  count(CASE WHEN (c)-[:SHARES_IDENTITY_WITH]-() THEN 1 END) AS total_shares_identity,
  count(CASE WHEN (c)-[:POSSIBLY_SAME_FRAUD_RING]-() THEN 1 END) AS total_ring_member;


// ============================================================
// BƯỚC 6.8 — KIỂM TRA TRADE-OFF: các Fraud thật bị luật đơn BỎ SÓT
// nhưng pipeline đa tầng BẮT ĐƯỢC (minh chứng giá trị gia tăng của KG)
// ============================================================
MATCH (c:Client)
WHERE c.groundTruthFraud = true
  AND NOT c:SuspectedMule
  AND (c)-[:POSSIBLY_SAME_FRAUD_RING]-()
RETURN c.id AS client_id,
       'Bị luật đơn bỏ sót, được pipeline đa tầng bắt được' AS note
LIMIT 20;

MATCH (c:Client)
WHERE c.groundTruthFraud = true
  AND NOT c:SuspectedMule
  AND NOT (c)-[:POSSIBLY_SAME_FRAUD_RING]-()
RETURN count(c) AS still_missed_by_both_methods;


// ============================================================
// HOÀN TẤT GIAI ĐOẠN 6 — SẴN SÀNG CHUYỂN SANG GIAI ĐOẠN 7 (TRỰC QUAN HOÁ)
// ============================================================

