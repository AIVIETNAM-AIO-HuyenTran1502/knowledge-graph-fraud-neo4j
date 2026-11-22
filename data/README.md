# Dữ liệu

Hai file trong thư mục này là **đầu vào trực tiếp** của pipeline Neo4j. Cả hai đều do notebook [`../notebooks/01_prepare_and_load.ipynb`](../notebooks/01_prepare_and_load.ipynb) sinh ra với `SEED = 12345`, nên chạy lại sẽ cho đúng kết quả này.

---

## `paysim_sample.csv` — 258.213 giao dịch (20 MB)

Mẫu lấy từ bộ PaySim trên Kaggle (6,3 triệu dòng): **giữ toàn bộ** giao dịch `isFraud = 1`, cộng thêm 250.000 giao dịch không gian lận lấy ngẫu nhiên. Các dòng giữ nguyên, không chỉnh sửa nội dung.

| Chỉ số | Giá trị |
|---|---:|
| Tổng giao dịch | 258.213 |
| Giao dịch gian lận (`isFraud = 1`) | 8.213 (3,18%) |
| Tài khoản khác nhau | 476.685 |
| — Client (`C*`) | 392.614 |
| — Merchant (`M*`) | 84.071 |
| Khoảng thời gian (`step`, giờ) | 1 – 743 |

Phân bố theo loại: `CASH_OUT` 92.088 · `PAYMENT` 84.073 · `CASH_IN` 55.340 · `TRANSFER` 25.123 · `DEBIT` 1.589

**Schema** (11 cột, giữ nguyên của PaySim):

| Cột | Ý nghĩa |
|---|---|
| `step` | Mốc thời gian, đơn vị giờ kể từ đầu mô phỏng |
| `type` | `CASH_IN`, `CASH_OUT`, `TRANSFER`, `PAYMENT`, `DEBIT` |
| `amount` | Số tiền giao dịch |
| `nameOrig` / `nameDest` | Tài khoản gửi / nhận. Tiền tố `C` = Client, `M` = Merchant |
| `oldbalanceOrg` / `newbalanceOrig` | Số dư tài khoản gửi trước và sau giao dịch |
| `oldbalanceDest` / `newbalanceDest` | Số dư tài khoản nhận trước và sau giao dịch |
| `isFraud` | Nhãn ground truth: giao dịch có phải gian lận không |
| `isFlaggedFraud` | Cờ cảnh báo của hệ thống mô phỏng (không dùng trong đề tài) |

---

## `identities_reduced.csv` — 66.382 định danh (4,1 MB)

> ⚠️ **Toàn bộ dữ liệu định danh ở đây là giả, sinh bằng thư viện Faker.** Không có SSN, email hay số điện thoại nào là của người thật. PaySim gốc không có trường định danh — phần này do đề tài tự tiêm vào để mô phỏng kịch bản gian lận danh tính.

Schema: `account_id`, `ssn`, `email`, `phone`

### Quy tắc tiêm định danh

| Nhóm | Quy tắc | Mục đích mô phỏng |
|---|---|---|
| Client bình thường | mỗi tài khoản một bộ định danh riêng | người dùng thật |
| Client liên quan gian lận | chia **cụm 4 tài khoản dùng chung một bộ định danh** | một kẻ gian dựng nhiều tài khoản mule từ một bộ giấy tờ |

### Vì sao chỉ 66.382 dòng

Bản đầy đủ có 392.614 dòng (một cho mỗi Client), nhưng nạp hết vào Neo4j thì quá chậm mà không thêm thông tin gì. Bản rút gọn giữ **100% Client liên quan gian lận** (16.382 tài khoản — không được cắt, vì đây là đối tượng cần phát hiện) cộng 50.000 Client bình thường lấy ngẫu nhiên làm nền so sánh.

Hệ quả: trong đồ thị, phần lớn Client sẽ không có node định danh gắn kèm. Điều này đúng như thiết kế.

### Kiểm chứng sau khi sinh

| Kiểm tra | Kết quả |
|---|---|
| Có Merchant nào bị gán định danh nhầm không? | 0 — đúng, Merchant không phải cá nhân |
| Số SSN được dùng chung bởi nhiều hơn 1 tài khoản | 4.097 |
| Số tài khoản liên quan tới SSN dùng chung | 16.385 |
| Cụm lớn nhất dùng chung một SSN | 5 tài khoản |

Lưu ý con số 16.385 so với 16.382 Client gian lận: **3 trường hợp chênh lệch là trùng ngẫu nhiên do Faker sinh lại cùng một SSN cho Client bình thường** — chính là hiện tượng Birthday Paradox được nêu ở mục Hạn chế của [README chính](../README.md). Đây là nguồn false positive có thật, không phải lỗi dữ liệu.

---

## Nguồn và giấy phép

Bộ dữ liệu gốc: **PaySim** — *Synthetic Financial Datasets For Fraud Detection*, tác giả Edgar Lopez-Rojas.
Tải tại Kaggle: <https://www.kaggle.com/datasets/ealaxi/paysim1>

PaySim là dữ liệu **mô phỏng**, không phải giao dịch thật của khách hàng nào. Bản trên Kaggle đã được thu nhỏ còn 1/4 so với mô phỏng gốc.

### Giấy phép

Bộ dữ liệu phát hành theo **[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)** (xác nhận qua Kaggle API, `licenseName: "CC BY-SA 4.0"`).

Vì vậy, trong repo này:

- **`data/` theo giấy phép CC BY-SA 4.0**, không phải MIT. Ai dùng lại dữ liệu ở đây phải ghi nguồn và giữ nguyên giấy phép này cho phần dẫn xuất.
- **Code, notebook và tài liệu theo [MIT](../LICENSE)**, nằm riêng ngoài thư mục `data/` nên không bị ràng buộc share-alike.
- `paysim_sample.csv` là tập con lấy mẫu, các dòng giữ nguyên không chỉnh sửa.
- `identities_reduced.csv` là dữ liệu do đề tài tự sinh bằng Faker, chỉ dùng chung cột `account_id` với PaySim; vẫn để theo CC BY-SA 4.0 cho nhất quán cả thư mục.

### Trích dẫn

Tác giả yêu cầu trích dẫn như sau:

> E. A. Lopez-Rojas, A. Elmir, and S. Axelsson. "PaySim: A financial mobile money simulator for fraud detection". In: *The 28th European Modeling and Simulation Symposium — EMSS*, Larnaca, Cyprus. 2016.

## Tái tạo lại từ đầu

```bash
pip install -r ../requirements.txt
# tải paysim.csv (6,3 triệu dòng) từ Kaggle, đặt cạnh notebook
jupyter notebook ../notebooks/01_prepare_and_load.ipynb
```
Chạy lần lượt các cell: lấy mẫu → phân loại tài khoản → sinh định danh bằng Faker → kiểm chứng → rút gọn. Với `SEED = 12345`, kết quả trùng khớp hai file trong thư mục này.
