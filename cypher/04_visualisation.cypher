// ============================================================
// 04 — TRỰC QUAN HOÁ
// ------------------------------------------------------------
// Trích đồ thị schema, mạng chia sẻ định danh và các ca case study để xuất ảnh.
// Chạy trước: 02_inference_9CQ.cypher.
// Mỗi khối dán vào một ô lệnh riêng trong Neo4j Browser, theo đúng thứ tự.
// ============================================================

// ============================================================
// GIAI ĐOẠN 7 — TRỰC QUAN HOÁ: TRÍCH XUẤT ĐỒ THỊ CHO BÁO CÁO
// Chạy từng khối trong Neo4j Browser, dùng nút export (góc kết quả)
// để lưu ảnh SVG/PNG sau mỗi lần chạy có hiển thị Graph view.
// ============================================================


// ============================================================
// 7.1 — GRAPH SCHEMA TỔNG THỂ (đối chiếu với Ontology thiết kế)
// ============================================================
CALL db.schema.visualization();
// -> Kết quả hiện Graph view. Dùng nút camera/export ở góc để lưu SVG/PNG.
// Dùng cho: Slide/Chương "Đối chiếu Graph Schema thực tế vs Ontology"

// Bản JSON chi tiết đầy đủ (label, property, kiểu dữ liệu) — lưu phụ lục báo cáo
CALL apoc.meta.schema() YIELD value
RETURN value;


// ============================================================
// 7.2 — CẤU TRÚC CƠ BẢN: Account – Transaction – Account
// (minh hoạ Ontology tầng gốc: PERFORMED / TO)
// ============================================================
MATCH p=(a:Account)-[:PERFORMED]->(t:Transaction)-[:TO]->(b:Account)
RETURN p
LIMIT 25;


// ============================================================
// 7.3 — CẤU TRÚC IDENTITY: Client – SSN/Email/Phone
// (minh hoạ Ontology tầng Identity: HAS_SSN / HAS_EMAIL / HAS_PHONE)
// ============================================================
MATCH p=(c:Client)-[:HAS_SSN|HAS_EMAIL|HAS_PHONE]->(i)
RETURN p
LIMIT 25;


// ============================================================
// 7.4 — MỘT CỤM FRAUD RING CỤ THỂ, ĐẦY ĐỦ NGỮ CẢNH
// (Account gốc + Transaction + Mule + Identity dùng chung — hình ảnh
// "toàn cảnh" nhất, nên dùng làm ảnh minh hoạ chính của báo cáo)
// ============================================================
MATCH (mule:Client:SuspectedMule)
WITH mule LIMIT 1
MATCH p1=(a:Account)-[:PERFORMED]->(:TRANSFER)-[:TO]->(mule)
MATCH p2=(mule)-[:PERFORMED]->(:CASH_OUT)
OPTIONAL MATCH p3=(mule)-[:HAS_SSN|HAS_EMAIL|HAS_PHONE]->(idAttr)<-[:HAS_SSN|HAS_EMAIL|HAS_PHONE]-(other:Client)
RETURN p1, p2, p3
LIMIT 25;


// ============================================================
// 7.5 — QUAN HỆ SUY DIỄN SHARES_IDENTITY_WITH (CQ6)
// ============================================================
MATCH p=(c1:Client)-[:SHARES_IDENTITY_WITH]->(c2:Client)
RETURN p
LIMIT 30;


// ============================================================
// 7.6 — SUSPECTED MULE + NGỮ CẢNH GIAO DỊCH (CQ5)
// ============================================================
MATCH p=(a:Account)-[:PERFORMED]->(t1:TRANSFER)-[:TO]->(mule:Client:SuspectedMule)-[:PERFORMED]->(t2:CASH_OUT)
RETURN p
LIMIT 25;


// ============================================================
// 7.7 — QUAN HỆ SUY DIỄN TẦNG 2: POSSIBLY_SAME_FRAUD_RING (CQ9)
// (đây là hình ảnh quan trọng nhất — thể hiện 2 Account không giao
// dịch trực tiếp nhưng được suy ra cùng ring)
// ============================================================
MATCH p=(a:Client)-[:POSSIBLY_SAME_FRAUD_RING]-(b:Client)
RETURN p
LIMIT 30;

// Nếu rỗng, dùng bản suy diễn nới lỏng (medium confidence) đã tạo ở Giai đoạn 5:
MATCH p=(a:Client)-[r:POSSIBLY_SAME_FRAUD_RING {confidence: 'medium'}]-(b:Client)
RETURN p
LIMIT 30;


// ============================================================
// 7.8 — TOÀN CẢNH: MULE + SHARED IDENTITY + FRAUD RING CÙNG LÚC
// (ảnh "tổng hợp" duy nhất, gộp cả 3 tầng suy diễn — dùng cho slide
// "Điểm nhấn CQ9" hoặc trang bìa phần kết quả)
// ============================================================
MATCH p=(c:Client:SuspectedMule)-[:SHARES_IDENTITY_WITH|POSSIBLY_SAME_FRAUD_RING]-(other:Client)
RETURN p
LIMIT 40;


// ============================================================
// 7.9 — MỘT CỘNG ĐỒNG (COMMUNITY) KHẢ NGHI CỤ THỂ, ĐẦY ĐỦ THÀNH VIÊN
// (minh hoạ trực quan cho Louvain — CQ7)
// ============================================================
MATCH (c:Client)
WITH c.communityId AS community, count(*) AS size
WHERE size >= 3 AND size <= 15
RETURN community, size
ORDER BY size DESC
LIMIT 1;
// Lấy giá trị "community" từ dòng kết quả trên, thay vào truy vấn dưới:

MATCH (c:Client {communityId: 0})   // <-- thay 0 bằng communityId lấy được ở trên
OPTIONAL MATCH p=(c)-[r:PERFORMED|TO|SHARES_IDENTITY_WITH|POSSIBLY_SAME_FRAUD_RING]-()
RETURN c, p
LIMIT 60;


// ============================================================
// 7.10 — XẾP HẠNG CENTRALITY TRONG CỘNG ĐỒNG KHẢ NGHI (CQ8)
// (bảng, không phải đồ thị — dùng cho báo cáo dạng số liệu)
// ============================================================
MATCH (c:Client)
WITH c.communityId AS community, count(*) AS size
WHERE size >= 3 AND size <= 15
WITH collect(community) AS suspiciousCommunities
MATCH (c:Client)
WHERE c.communityId IN suspiciousCommunities
RETURN c.id AS client_id, c.communityId AS community,
       c.betweennessScore AS centrality, c:SuspectedMule AS isMule
ORDER BY c.betweennessScore DESC
LIMIT 15;


// ============================================================
// 7.11 — SO SÁNH TRỰC QUAN: TRƯỚC VÀ SAU SUY DIỄN
// (2 câu lệnh chạy liền nhau để chụp 2 ảnh đối chiếu:
//  "chỉ có dữ liệu gốc" vs "sau khi có quan hệ suy diễn")
// ============================================================

// Ảnh A — CHỈ dữ liệu gốc (không có quan hệ suy diễn)
MATCH p=(a:Account)-[:PERFORMED]->(t:Transaction)-[:TO]->(b:Account)
WHERE a.id IN [
  // dán vào đây danh sách id của 1 fraud ring cụ thể đã tìm được ở 7.4/7.8
]
RETURN p;

// Ảnh B — CÓ thêm quan hệ suy diễn (SHARES_IDENTITY_WITH, POSSIBLY_SAME_FRAUD_RING)
MATCH p=(a:Client)-[:PERFORMED|TO|SHARES_IDENTITY_WITH|POSSIBLY_SAME_FRAUD_RING*1..2]-(b:Client)
WHERE a.id IN [
  // dùng lại đúng danh sách id ở Ảnh A
]
RETURN p
LIMIT 40;


// ============================================================
// 7.12 — XUẤT DỮ LIỆU RA FILE (phục vụ vẽ lại bằng công cụ khác
// nếu cần, ví dụ Python/networkx hoặc Gephi)
// ============================================================

// Xuất subgraph fraud ring ra GraphML (cần plugin APOC)
CALL apoc.export.graphml.query(
  "MATCH p=(c:Client:SuspectedMule)-[:SHARES_IDENTITY_WITH|POSSIBLY_SAME_FRAUD_RING]-(other:Client) RETURN p",
  "fraud_ring_export.graphml",
  {}
) YIELD file, nodes, relationships, properties, time
RETURN file, nodes, relationships, properties, time;
// File được lưu vào thư mục import/ của Neo4j — copy ra ngoài để dùng với Gephi/Python nếu cần

// Xuất toàn bộ schema + vài dòng mẫu ra JSON (phụ lục báo cáo)
CALL apoc.export.json.query(
  "MATCH (c:Client:SuspectedMule)-[r:POSSIBLY_SAME_FRAUD_RING]-(other:Client) RETURN c.id AS mule_id, other.id AS linked_id, r.confidence AS confidence",
  "fraud_ring_pairs.json",
  {}
) YIELD file, nodes, relationships, properties
RETURN file, nodes, relationships, properties;


// ============================================================
// GHI CHÚ SỬ DỤNG
// - Mỗi câu RETURN p (path) sẽ tự động hiển thị dạng Graph view
//   trong Neo4j Browser — dùng nút export ở góc kết quả để lưu SVG/PNG.
// - Trước khi chụp ảnh: click vào từng loại node để đổi màu/caption
//   (ví dụ hiển thị c.id thay vì id nội bộ) cho ảnh dễ đọc hơn.
// - Thứ tự khuyến nghị đưa vào báo cáo:
//   7.1 (schema) -> 7.2/7.3 (cấu trúc cơ bản) -> 7.6 (mule)
//   -> 7.5 (shared identity) -> 7.9 (community) -> 7.7/7.8 (fraud ring, ảnh chính)
// ============================================================
