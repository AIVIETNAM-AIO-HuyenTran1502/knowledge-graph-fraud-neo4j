// ============================================================
// 01 — NẠP DỮ LIỆU VÀO NEO4J
// ------------------------------------------------------------
// Tạo constraint, nạp 258.213 giao dịch và 66.382 định danh theo lô, validate đồ thị sau khi nạp.
// Chạy trước: (không có — đây là bước đầu tiên). Cần 2 file trong data/ đặt vào thư mục import của Neo4j.
// Mỗi khối dán vào một ô lệnh riêng trong Neo4j Browser, theo đúng thứ tự.
// ============================================================

// ============================================================
// PIPELINE NẠP DỮ LIỆU PAYSIM VÀO NEO4J — PHIÊN BẢN IDEMPOTENT
// Chạy TUẦN TỰ từng khối theo đúng thứ tự đánh số bên dưới.
// Mỗi khối dán vào 1 ô lệnh (query box) riêng trong Neo4j Browser.
// Có thể chạy lại bất kỳ khối nào bao nhiêu lần cũng không sợ trùng dữ liệu.
// ============================================================


// ============================================================
// BƯỚC 0 — XOÁ SẠCH DỮ LIỆU CŨ (chỉ chạy nếu đang làm lại từ đầu
// do phát hiện dữ liệu bị trùng lặp ở lần nạp trước)
// ============================================================
MATCH (n) DETACH DELETE n;


// ============================================================
// BƯỚC 1 — TẠO CONSTRAINT (bắt buộc chạy trước khi nạp dữ liệu)
// Lưu ý: có thêm constraint mới cho txKey so với bản trước đây
// ============================================================
CREATE CONSTRAINT client_id IF NOT EXISTS FOR (c:Client) REQUIRE c.id IS UNIQUE;
CREATE CONSTRAINT merchant_id IF NOT EXISTS FOR (m:Merchant) REQUIRE m.id IS UNIQUE;
CREATE CONSTRAINT account_id IF NOT EXISTS FOR (a:Account) REQUIRE a.id IS UNIQUE;
CREATE CONSTRAINT tx_key_unique IF NOT EXISTS FOR (t:Transaction) REQUIRE t.txKey IS UNIQUE;
CREATE CONSTRAINT ssn_unique IF NOT EXISTS FOR (s:SSN) REQUIRE s.ssn IS UNIQUE;
CREATE CONSTRAINT email_unique IF NOT EXISTS FOR (e:Email) REQUIRE e.email IS UNIQUE;
CREATE CONSTRAINT phone_unique IF NOT EXISTS FOR (p:Phone) REQUIRE p.phoneNumber IS UNIQUE;

// Kiểm tra lại đã tạo đủ 7 constraint chưa trước khi sang bước tiếp theo
SHOW CONSTRAINTS;


// ============================================================
// BƯỚC 2 — NẠP paysim_sample.csv — ĐOẠN 1/4 (dòng 1 → 65,000)
// ============================================================
:auto LOAD CSV WITH HEADERS FROM 'file:///paysim_sample.csv' AS row
WITH row, linenumber() AS ln
WHERE ln > 0 AND ln <= 65000
WITH row, row.nameOrig + '-' + row.nameDest + '-' + row.step + '-' + row.amount + '-' + row.type AS tx_key
CALL {
  WITH row, tx_key
  MERGE (orig:Account {id: row.nameOrig})
    ON CREATE SET orig:Client, orig.accountType = 'Client'
  FOREACH (_ IN CASE WHEN row.nameOrig STARTS WITH 'M' THEN [1] ELSE [] END |
    SET orig:Merchant REMOVE orig:Client SET orig.accountType = 'Merchant'
  )
  MERGE (dest:Account {id: row.nameDest})
    ON CREATE SET dest:Client, dest.accountType = 'Client'
  FOREACH (_ IN CASE WHEN row.nameDest STARTS WITH 'M' THEN [1] ELSE [] END |
    SET dest:Merchant REMOVE dest:Client SET dest.accountType = 'Merchant'
  )
  MERGE (t:Transaction {txKey: tx_key})
    ON CREATE SET
      t.id = randomUUID(),
      t.step = toInteger(row.step),
      t.amount = toFloat(row.amount),
      t.oldBalanceOrig = toFloat(row.oldbalanceOrg),
      t.newBalanceOrig = toFloat(row.newbalanceOrig),
      t.oldBalanceDest = toFloat(row.oldbalanceDest),
      t.newBalanceDest = toFloat(row.newbalanceDest),
      t.isFraud = toInteger(row.isFraud),
      t.isFlaggedFraud = toInteger(row.isFlaggedFraud)
  WITH t, row, orig, dest
  CALL apoc.create.addLabels(t, [row.type]) YIELD node
  MERGE (orig)-[:PERFORMED]->(node)
  MERGE (node)-[:TO]->(dest)
} IN TRANSACTIONS OF 2000 ROWS;


// ============================================================
// BƯỚC 3 — NẠP paysim_sample.csv — ĐOẠN 2/4 (dòng 65,001 → 130,000)
// ============================================================
:auto LOAD CSV WITH HEADERS FROM 'file:///paysim_sample.csv' AS row
WITH row, linenumber() AS ln
WHERE ln > 65000 AND ln <= 130000
WITH row, row.nameOrig + '-' + row.nameDest + '-' + row.step + '-' + row.amount + '-' + row.type AS tx_key
CALL {
  WITH row, tx_key
  MERGE (orig:Account {id: row.nameOrig})
    ON CREATE SET orig:Client, orig.accountType = 'Client'
  FOREACH (_ IN CASE WHEN row.nameOrig STARTS WITH 'M' THEN [1] ELSE [] END |
    SET orig:Merchant REMOVE orig:Client SET orig.accountType = 'Merchant'
  )
  MERGE (dest:Account {id: row.nameDest})
    ON CREATE SET dest:Client, dest.accountType = 'Client'
  FOREACH (_ IN CASE WHEN row.nameDest STARTS WITH 'M' THEN [1] ELSE [] END |
    SET dest:Merchant REMOVE dest:Client SET dest.accountType = 'Merchant'
  )
  MERGE (t:Transaction {txKey: tx_key})
    ON CREATE SET
      t.id = randomUUID(),
      t.step = toInteger(row.step),
      t.amount = toFloat(row.amount),
      t.oldBalanceOrig = toFloat(row.oldbalanceOrg),
      t.newBalanceOrig = toFloat(row.newbalanceOrig),
      t.oldBalanceDest = toFloat(row.oldbalanceDest),
      t.newBalanceDest = toFloat(row.newbalanceDest),
      t.isFraud = toInteger(row.isFraud),
      t.isFlaggedFraud = toInteger(row.isFlaggedFraud)
  WITH t, row, orig, dest
  CALL apoc.create.addLabels(t, [row.type]) YIELD node
  MERGE (orig)-[:PERFORMED]->(node)
  MERGE (node)-[:TO]->(dest)
} IN TRANSACTIONS OF 2000 ROWS;


// ============================================================
// BƯỚC 4 — NẠP paysim_sample.csv — ĐOẠN 3/4 (dòng 130,001 → 195,000)
// ============================================================
:auto LOAD CSV WITH HEADERS FROM 'file:///paysim_sample.csv' AS row
WITH row, linenumber() AS ln
WHERE ln > 130000 AND ln <= 195000
WITH row, row.nameOrig + '-' + row.nameDest + '-' + row.step + '-' + row.amount + '-' + row.type AS tx_key
CALL {
  WITH row, tx_key
  MERGE (orig:Account {id: row.nameOrig})
    ON CREATE SET orig:Client, orig.accountType = 'Client'
  FOREACH (_ IN CASE WHEN row.nameOrig STARTS WITH 'M' THEN [1] ELSE [] END |
    SET orig:Merchant REMOVE orig:Client SET orig.accountType = 'Merchant'
  )
  MERGE (dest:Account {id: row.nameDest})
    ON CREATE SET dest:Client, dest.accountType = 'Client'
  FOREACH (_ IN CASE WHEN row.nameDest STARTS WITH 'M' THEN [1] ELSE [] END |
    SET dest:Merchant REMOVE dest:Client SET dest.accountType = 'Merchant'
  )
  MERGE (t:Transaction {txKey: tx_key})
    ON CREATE SET
      t.id = randomUUID(),
      t.step = toInteger(row.step),
      t.amount = toFloat(row.amount),
      t.oldBalanceOrig = toFloat(row.oldbalanceOrg),
      t.newBalanceOrig = toFloat(row.newbalanceOrig),
      t.oldBalanceDest = toFloat(row.oldbalanceDest),
      t.newBalanceDest = toFloat(row.newbalanceDest),
      t.isFraud = toInteger(row.isFraud),
      t.isFlaggedFraud = toInteger(row.isFlaggedFraud)
  WITH t, row, orig, dest
  CALL apoc.create.addLabels(t, [row.type]) YIELD node
  MERGE (orig)-[:PERFORMED]->(node)
  MERGE (node)-[:TO]->(dest)
} IN TRANSACTIONS OF 2000 ROWS;


// ============================================================
// BƯỚC 5 — NẠP paysim_sample.csv — ĐOẠN 4/4 (dòng 195,001 → hết, 258,213)
// ============================================================
:auto LOAD CSV WITH HEADERS FROM 'file:///paysim_sample.csv' AS row
WITH row, linenumber() AS ln
WHERE ln > 195000 AND ln <= 258213
WITH row, row.nameOrig + '-' + row.nameDest + '-' + row.step + '-' + row.amount + '-' + row.type AS tx_key
CALL {
  WITH row, tx_key
  MERGE (orig:Account {id: row.nameOrig})
    ON CREATE SET orig:Client, orig.accountType = 'Client'
  FOREACH (_ IN CASE WHEN row.nameOrig STARTS WITH 'M' THEN [1] ELSE [] END |
    SET orig:Merchant REMOVE orig:Client SET orig.accountType = 'Merchant'
  )
  MERGE (dest:Account {id: row.nameDest})
    ON CREATE SET dest:Client, dest.accountType = 'Client'
  FOREACH (_ IN CASE WHEN row.nameDest STARTS WITH 'M' THEN [1] ELSE [] END |
    SET dest:Merchant REMOVE dest:Client SET dest.accountType = 'Merchant'
  )
  MERGE (t:Transaction {txKey: tx_key})
    ON CREATE SET
      t.id = randomUUID(),
      t.step = toInteger(row.step),
      t.amount = toFloat(row.amount),
      t.oldBalanceOrig = toFloat(row.oldbalanceOrg),
      t.newBalanceOrig = toFloat(row.newbalanceOrig),
      t.oldBalanceDest = toFloat(row.oldbalanceDest),
      t.newBalanceDest = toFloat(row.newbalanceDest),
      t.isFraud = toInteger(row.isFraud),
      t.isFlaggedFraud = toInteger(row.isFlaggedFraud)
  WITH t, row, orig, dest
  CALL apoc.create.addLabels(t, [row.type]) YIELD node
  MERGE (orig)-[:PERFORMED]->(node)
  MERGE (node)-[:TO]->(dest)
} IN TRANSACTIONS OF 2000 ROWS;


// ============================================================
// BƯỚC 6 — KIỂM TRA TRƯỚC KHI SANG IDENTITY
// Bắt buộc phải khớp đúng 2 con số này trước khi chạy Bước 7-8
// ============================================================
MATCH (t:Transaction) RETURN count(t) AS total_transactions;   // phải = 258213
MATCH (a:Account) RETURN count(a) AS total_accounts;            // phải = 476685

// Kiểm tra không còn trùng lặp (mỗi cặp orig-dest-step-amount chỉ nên xuất hiện tối đa vài lần tự nhiên, không đồng loạt x8 như trước)
MATCH (o:Account)-[:PERFORMED]->(t:Transaction)-[:TO]->(d:Account)
WITH o.id AS orig, d.id AS dest, t.step AS step, t.amount AS amount, count(*) AS cnt
WHERE cnt > 2
RETURN orig, dest, step, amount, cnt
ORDER BY cnt DESC
LIMIT 10;
// Nếu bảng này trả về rỗng hoặc chỉ vài dòng cnt thấp -> dữ liệu sạch, có thể sang Bước 7


// ============================================================
// BƯỚC 7 — NẠP identities_reduced.csv — ĐOẠN 1/2 (dòng 1 → 35,000)
// ============================================================
:auto LOAD CSV WITH HEADERS FROM 'file:///identities_reduced.csv' AS row
WITH row, linenumber() AS ln
WHERE ln > 0 AND ln <= 35000
CALL {
  WITH row
  MATCH (c:Client {id: row.account_id})
  MERGE (s:SSN {ssn: row.ssn})
  MERGE (e:Email {email: row.email})
  MERGE (p:Phone {phoneNumber: row.phone})
  MERGE (c)-[:HAS_SSN]->(s)
  MERGE (c)-[:HAS_EMAIL]->(e)
  MERGE (c)-[:HAS_PHONE]->(p)
} IN TRANSACTIONS OF 2000 ROWS;


// ============================================================
// BƯỚC 8 — NẠP identities_reduced.csv — ĐOẠN 2/2 (dòng 35,001 → hết, ~66,382)
// ============================================================
:auto LOAD CSV WITH HEADERS FROM 'file:///identities_reduced.csv' AS row
WITH row, linenumber() AS ln
WHERE ln > 35000 AND ln <= 66382
CALL {
  WITH row
  MATCH (c:Client {id: row.account_id})
  MERGE (s:SSN {ssn: row.ssn})
  MERGE (e:Email {email: row.email})
  MERGE (p:Phone {phoneNumber: row.phone})
  MERGE (c)-[:HAS_SSN]->(s)
  MERGE (c)-[:HAS_EMAIL]->(e)
  MERGE (c)-[:HAS_PHONE]->(p)
} IN TRANSACTIONS OF 2000 ROWS;


// ============================================================
// BƯỚC 9 — VALIDATE CUỐI CÙNG — bắt buộc kiểm tra trước khi sang Giai đoạn 5
// ============================================================

// 9a. Đếm tổng quan
MATCH (t:Transaction) RETURN count(t) AS total_transactions;      // = 258213
MATCH (t:Transaction {isFraud: 1}) RETURN count(t) AS total_fraud; // = 8213
MATCH (a:Account) RETURN count(a) AS total_accounts;               // = 476685
MATCH (s:SSN) RETURN count(s) AS total_ssn;
MATCH (e:Email) RETURN count(e) AS total_email;
MATCH (p:Phone) RETURN count(p) AS total_phone;

// 9b. Transaction không có PERFORMED (phải = 0, nếu khác 0 là có lỗi)
MATCH (t:Transaction) WHERE NOT (t)<-[:PERFORMED]-() RETURN count(t) AS orphan_transactions;

// 9c. Kiểm tra account_id trong identities_reduced.csv có Client nào bị "mồ côi" không (chưa khớp)
LOAD CSV WITH HEADERS FROM 'file:///identities_reduced.csv' AS row
WITH collect(row.account_id) AS csv_ids
MATCH (c:Client)
WITH csv_ids, collect(c.id) AS db_ids
WITH [id IN csv_ids WHERE NOT id IN db_ids] AS missing
RETURN size(missing) AS missing_count, missing[0..10] AS sample_missing;
// missing_count phải = 0. Nếu khác 0, chạy lại Bước 7-8.

// 9d. Xem nhanh trực quan một phần đồ thị để kiểm tra bằng mắt
MATCH p=(a:Account)-[:PERFORMED]->(t:Transaction)-[:TO]->(b:Account)
RETURN p LIMIT 25;

MATCH p=(c:Client)-[:HAS_SSN|HAS_EMAIL|HAS_PHONE]->(i)
RETURN p LIMIT 25;

// ============================================================
// HOÀN TẤT GIAI ĐOẠN 4 — SẴN SÀNG CHUYỂN SANG GIAI ĐOẠN 5 (SUY DIỄN)
// ============================================================

