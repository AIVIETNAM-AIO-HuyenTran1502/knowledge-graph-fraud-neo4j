// ============================================================
// 02 — SUY DIỄN: TRẢ LỜI 9 COMPETENCY QUESTIONS
// ------------------------------------------------------------
// Suy diễn 3 tầng: luật SuspectedMule, SHARES_IDENTITY_WITH, Louvain + Node Similarity + Betweenness, rồi POSSIBLY_SAME_FRAUD_RING.
// Chạy trước: 01_load_pipeline.cypher. Cần plugin Graph Data Science (GDS).
// Mỗi khối dán vào một ô lệnh riêng trong Neo4j Browser, theo đúng thứ tự.
// ============================================================

// ============================================================
// GIAI ĐOẠN 5 — SUY DIỄN: TRẢ LỜI 9 COMPETENCY QUESTIONS
// Chạy TUẦN TỰ từng khối theo đúng thứ tự, mỗi khối 1 ô lệnh Neo4j Browser
// ============================================================


// ============================================================
// TẦNG 1 — TRA CỨU TRỰC TIẾP (CQ1, CQ2, CQ3)
// ============================================================

// --- CQ1: Một Account cụ thể đã thực hiện những Transaction nào? ---
// (Thay 'C778364717' bằng id account muốn xem)
MATCH (a:Account {id: 'C778364717'})-[:PERFORMED]->(t:Transaction)
RETURN a.id, t.id, t.type, t.amount, t.step, t.isFraud
ORDER BY t.step
LIMIT 25;

// --- CQ2: Những Transaction nào có isFraud = true? ---
MATCH (t:Transaction {isFraud: 1})
RETURN t.id, t.type, t.amount, t.step
ORDER BY t.step
LIMIT 25;

MATCH (t:Transaction {isFraud: 1})
RETURN count(t) AS total_fraud_transactions;

// --- CQ3: Account nào là Merchant, Account nào là Client? ---
MATCH (a:Account)
RETURN a.accountType, count(*) AS total
ORDER BY total DESC;


// ============================================================
// TẦNG 2 — MULTI-HOP (CQ4, CQ5, CQ6)
// ============================================================

// --- CQ4: Hai Account không giao dịch trực tiếp có từng chuyển tiền
//          qua cùng một Account trung gian không? ---
MATCH (a:Account)-[:PERFORMED]->(:Transaction)-[:TO]->(shared:Account),
      (b:Account)-[:PERFORMED]->(:Transaction)-[:TO]->(shared)
WHERE a <> b
  AND NOT (a)-[:PERFORMED]->(:Transaction)-[:TO]->(b)
  AND NOT (b)-[:PERFORMED]->(:Transaction)-[:TO]->(a)
WITH a, b, shared, count(*) AS commonLinks
WHERE commonLinks >= 2
RETURN a.id, b.id, shared.id AS via, commonLinks
ORDER BY commonLinks DESC
LIMIT 20;

// --- CQ5: Account nào có phải "mule" không — nhận TRANSFER rồi
//          CASH_OUT gần như ngay sau đó? ---
MATCH (a:Account)-[:PERFORMED]->(t1:TRANSFER)-[:TO]->(mule:Client),
      (mule)-[:PERFORMED]->(t2:CASH_OUT)
WHERE t2.step - t1.step <= 1
  AND t2.amount >= 0.9 * t1.amount
SET mule:SuspectedMule
RETURN count(DISTINCT mule) AS suspected_mules;

// Xem chi tiết danh sách mule đã phát hiện
MATCH (m:Client:SuspectedMule)
RETURN m.id
LIMIT 25;

// --- CQ6: Những Client nào dùng chung SSN/Email/Phone với nhau? ---
MATCH (c1:Client)-[:HAS_SSN|HAS_EMAIL|HAS_PHONE]->(shared)<-[:HAS_SSN|HAS_EMAIL|HAS_PHONE]-(c2:Client)
WHERE elementId(c1) < elementId(c2)
MERGE (c1)-[r:SHARES_IDENTITY_WITH]->(c2)
SET r.via = labels(shared)[0]
RETURN count(r) AS shared_identity_pairs;

// Xem chi tiết vài cặp
MATCH (c1:Client)-[r:SHARES_IDENTITY_WITH]->(c2:Client)
RETURN c1.id, c2.id, r.via
LIMIT 25;


// ============================================================
// TẦNG 3 — SUY DIỄN THUẬT TOÁN (CQ7, CQ8, CQ9)
// ============================================================

// --- Chuẩn bị: xoá graph projection cũ nếu đã từng tạo sai trước đó ---
CALL gds.graph.exists('fraudGraph') YIELD exists
WITH exists WHERE exists = true
CALL gds.graph.drop('fraudGraph') YIELD graphName
RETURN graphName;

// --- Project lại fraudGraph ĐÚNG CÁCH ---
// Lưu ý quan trọng: Client KHÔNG nối trực tiếp với Client trong dữ liệu gốc
// (luôn phải đi qua Transaction: Client-PERFORMED->Transaction-TO->Client).
// Vì vậy phải dùng Cypher Projection để "thu gọn" quan hệ 2 chặng
// thành 1 cạnh Client-Client trực tiếp trước khi đưa vào GDS.
// Nếu chỉ project ['Client'] với relationship PERFORMED_TO như cách cũ,
// relationshipCount sẽ luôn = 0 vì Transaction không nằm trong node projection.
CALL gds.graph.project.cypher(
  'fraudGraph',
  'MATCH (c:Client) RETURN id(c) AS id',
  'MATCH (c1:Client)-[:PERFORMED]->(:Transaction)-[:TO]->(c2:Client)
   WHERE c1 <> c2
   RETURN id(c1) AS source, id(c2) AS target'
)
YIELD graphName, nodeCount, relationshipCount;
// Kiểm tra ngay: relationshipCount PHẢI > 0 (nếu vẫn = 0, dừng lại kiểm tra dữ liệu trước khi tiếp tục)


// --- CQ7: Có tồn tại cụm (cluster) Account nào kết nối bất thường
//          chặt chẽ so với phần còn lại mạng lưới không? ---
CALL gds.louvain.write('fraudGraph', {
  writeProperty: 'communityId'
})
YIELD communityCount, modularity;
// modularity lần này phải ra số thực (không còn NaN như lần chạy sai trước đó)
// communityCount phải nhỏ hơn nhiều so với tổng số Client (392,613)

// Lọc ra các cộng đồng nhỏ, dày đặc — dấu hiệu ring gian lận
MATCH (c:Client)
WITH c.communityId AS community, count(*) AS size
WHERE size >= 3 AND size <= 15
RETURN community, size
ORDER BY size DESC
LIMIT 20;


// --- Project riêng đồ thị Identity cho Node Similarity (dùng lại nếu chưa tạo) ---
CALL gds.graph.exists('identityGraph') YIELD exists
WITH exists WHERE exists = true
CALL gds.graph.drop('identityGraph') YIELD graphName
RETURN graphName;

CALL gds.graph.project(
  'identityGraph',
  ['Client', 'SSN', 'Email', 'Phone'],
  {
    HAS_SSN: {orientation: 'UNDIRECTED'},
    HAS_EMAIL: {orientation: 'UNDIRECTED'},
    HAS_PHONE: {orientation: 'UNDIRECTED'}
  }
);

CALL gds.nodeSimilarity.write('identityGraph', {
  writeRelationshipType: 'SIMILAR_IDENTITY',
  writeProperty: 'similarityScore',
  similarityCutoff: 0.5
});

// Kết hợp CQ6 + CQ7: chỉ giữ cặp Client vừa cùng community VỪA similarity cao
MATCH (c1:Client)-[s:SIMILAR_IDENTITY]->(c2:Client)
WHERE c1.communityId = c2.communityId AND s.similarityScore >= 0.5
RETURN c1.id, c2.id, s.similarityScore
ORDER BY s.similarityScore DESC
LIMIT 25;


// --- CQ8: Trong một cụm gian lận đã xác định, Account nào đóng vai trò
//          trung tâm/khởi phát? ---
CALL gds.betweenness.write('fraudGraph', {
  writeProperty: 'betweennessScore'
});

// Lấy danh sách community khả nghi TỰ ĐỘNG (không cần copy tay như trước)
// rồi xếp hạng centrality chỉ trong các community đó
MATCH (c:Client)
WITH c.communityId AS community, count(*) AS size
WHERE size >= 3 AND size <= 15
WITH collect(community) AS suspiciousCommunities
MATCH (c:Client)
WHERE c.communityId IN suspiciousCommunities
RETURN c.id, c.communityId, c.betweennessScore, c:SuspectedMule AS isMule
ORDER BY c.betweennessScore DESC
LIMIT 20;


// --- CQ9: Hai Account không có giao dịch trực tiếp hay identity chung,
//          nhưng có khả năng thuộc cùng fraud ring không? (suy diễn tầng 2,
//          kết hợp cả 3 tầng: Mule + Community + Similarity) ---
MATCH (a:Client)-[:SHARES_IDENTITY_WITH]-(b:Client)
WHERE a:SuspectedMule AND b:SuspectedMule
  AND a.communityId = b.communityId
MERGE (a)-[r:POSSIBLY_SAME_FRAUD_RING]->(b)
SET r.confidence = 'high'
RETURN count(r) AS confirmed_ring_pairs;

// Nếu confirmed_ring_pairs vẫn = 0, dùng điều kiện nới lỏng hơn:
// chỉ cần SHARES_IDENTITY_WITH + cùng community bất thường (không bắt buộc cả 2 đều là SuspectedMule)
MATCH (a:Client)-[:SHARES_IDENTITY_WITH]-(b:Client)
WHERE a.communityId = b.communityId
WITH a.communityId AS community, count(*) AS size
WHERE size >= 3 AND size <= 15
WITH collect(community) AS suspiciousCommunities
MATCH (a:Client)-[:SHARES_IDENTITY_WITH]-(b:Client)
WHERE a.communityId IN suspiciousCommunities AND a.communityId = b.communityId
MERGE (a)-[r:POSSIBLY_SAME_FRAUD_RING]->(b)
SET r.confidence = 'medium'
RETURN count(r) AS confirmed_ring_pairs_relaxed;


// ============================================================
// XEM TRỰC QUAN KẾT QUẢ SUY DIỄN (đồ thị, cho Giai đoạn 7)
// ============================================================
MATCH p=(c:Client:SuspectedMule)-[:SHARES_IDENTITY_WITH|POSSIBLY_SAME_FRAUD_RING]-(other:Client)
RETURN p
LIMIT 30;


// ============================================================
// BẢNG TỔNG HỢP: CQ ↔ CÂU LỆNH ↔ KẾT QUẢ MONG ĐỢI
// CQ1  -> Tầng 1, truy vấn PERFORMED trực tiếp
// CQ2  -> Tầng 1, lọc isFraud = 1
// CQ3  -> Tầng 1, group theo accountType
// CQ4  -> Tầng 2, pattern 2-hop qua Account trung gian
// CQ5  -> Tầng 2, rule-based Suspected Mule
// CQ6  -> Tầng 2, suy diễn SHARES_IDENTITY_WITH
// CQ7  -> Tầng 3, Louvain Community Detection (đã fix Cypher Projection)
// CQ8  -> Tầng 3, Betweenness Centrality trong community khả nghi
// CQ9  -> Tầng 3, suy diễn tầng 2 kết hợp Mule + Community + Similarity
// ============================================================

