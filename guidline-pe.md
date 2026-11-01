Dưới đây là **toàn bộ luồng hoạt động (Flow & Architecture Logic) chuẩn xác 100%** của file [pe-tool.sh](file:///d:/FPT_UNIVERSITY/SEMESTER_07/pe-practical-before/sdn/pe-tool.sh) từ lúc bạn gõ lệnh chạy cho đến khi ra được một project hoàn chỉnh:

---

```
                       LUỒNG TỔNG QUAN CỦA PE-TOOL.SH
┌────────────────────────────────────────────────────────────────────────┐
│ BƯỚC 1: INTERACTIVE CLI (Hỏi & Thu thập thông tin từ User qua Terminal) │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ BƯỚC 2: BASH SHELL INIT (Tạo khung Express, cài thư viện & ghi .env)   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ BƯỚC 3: EXPORT CONFIG (.generator_config.json)                         │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ BƯỚC 4: NODE.JS GENERATOR ENGINE (.build_project.js chạy in-line)      │
│   ├── Sinh Constants (errors.js, auth.js, routes.js, messages.js)      │
│   ├── Sinh Validators & Helpers (validators.js, hbsHelpers.js)         │
│   ├── Sinh Middlewares (authPage.js, authJWT.js, errorHandler.js)      │
│   ├── Sinh Mongoose Models (models/*.js)                               │
│   ├── Sinh Repositories (repositories/*.js)                            │
│   ├── Sinh Services có Validate (services/*.js)                        │
│   ├── Sinh Controllers (controllers/auth.js & controllers/*.js)        │
│   ├── Sinh Routes (page.js & api.js)                                   │
│   ├── Sinh Views HBS (login, list, cards, add, edit, detail)           │
│   └── Cấu hình app.js & bin/www                                        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ BƯỚC 5: DATABASE SEEDING (.provision_db.js) & CLEANUP DỌN DẸP         │
└────────────────────────────────────────────────────────────────────────┘
```

---

### CHI TIẾT TỪNG BƯỚC HOẠT ĐỘNG:

#### 1. Bước 1: Giao tiếp CLI (Interactive Prompts)

Khi bạn gõ `./pe-tool.sh`, bash thực hiện hỏi từng thông tin:

1. **Thông tin chung**: Tên dự án (`PROJECT_NAME`), Tên Database (`DB_NAME`).
2. **Manager Entity (Bảng User/Admin đăng nhập)**:
   - Tên model (mặc định: `User` hoặc `Admin`).
   - Tên trường username (ví dụ: `username`, `email`).
   - Tên trường password (ví dụ: `password`).
   - Các trường bổ sung nếu có (nhập bằng cú pháp DSL).
   - Chọn View hiển thị (Table, Card, Both, None).
3. **CHỌN CƠ CHẾ AUTHENTICATION (`AUTH_MODE`)**:
   - `[1] Express Session`: Cookie session truyền thống.
   - `[2] JWT in HttpOnly Cookie`: JWT lưu trong Cookie bảo mật.
   - `[3] JWT in LocalStorage`: JWT gửi về Client lưu vào Browser localStorage.
4. **Independent Entities (Bảng độc lập / Danh mục, không có khóa ngoại)**:
   - Vòng lặp `while` hỏi tên từng Entity (ví dụ: `Category`, `Brand`, `Department`).
   - Nhập danh sách fields dạng DSL (hỗ trợ nhập nhiều dòng kết thúc bằng `done`).
5. **Dependent Entities (Bảng chính có chứa khóa ngoại FK)**:
   - Vòng lặp `while` hỏi tên Entity chính (ví dụ: `Blog`, `Car`, `Hotel`, `Movie`).
   - Hỏi trường tham chiếu FK đến bảng độc lập nào (ví dụ: `category: Category`).
   - Nhập danh sách fields dạng DSL.

---

#### 2. Bước 2: Chuẩn bị môi trường & Cài đặt gói (Bash Steps)

1. **Kiểm tra công cụ**: Xác nhận máy tính đã có `node`, `npm`, và `mongod` đang chạy.
2. **Tạo khung Express Generator**:
   ```bash
   npx --yes express-generator --view=hbs "$PROJECT_NAME"
   cd "$PROJECT_NAME"
   ```
3. **Cài đặt Dependency có điều kiện (Rất quan trọng)**:
   - Nếu chọn `[1] session`: Cài `dotenv mongoose jsonwebtoken bcryptjs express-session cookie-parser hbs`.
   - Nếu chọn `[2]` hoặc `[3]`: **Loại bỏ hoàn toàn `express-session`** khỏi lệnh cài đặt để file `package.json` sạch sẽ 100%.
   - Cài thêm `nodemon` cho môi trường dev.
4. **Tạo file `.env`**: Ghi đúng 3 dòng: `PORT=5000`, `MONGODB_URI`, `JWT_SECRET`.

---

#### 3. Bước 3: Xuất cấu hình `.generator_config.json`

Bash gom toàn bộ thông tin đã thu thập ở Bước 1 (danh sách Model, fields, validation flags, quan hệ 1-N, layout, `authMode`) ghi vào file tạm `.generator_config.json`.

---

#### 4. Bước 4: Bộ máy sinh mã nguồn (Node.js Generator Engine)

File script `.build_project.js` được thực thi và tự động sinh mã theo **Clean Architecture 3 lớp**:

1. **Tạo thư mục**: `models`, `repositories`, `services`, `controllers`, `routes`, `middlewares`, `utils/constants`, `utils/helpers`, `views/...`.
2. **Sinh Constants & Messages**:
   - `utils/constants/errors.js`: Định nghĩa `STATUS` (200, 400, 401, 404, 500) và `MESSAGES` (thông báo lỗi validate chuẩn, độc lập để bạn dễ sửa trong phòng thi).
   - `utils/constants/auth.js`: Chứa `AUTH_MODE`, `COOKIE_NAME`, `USER_FIELD`, `PASS_FIELD`.
   - `utils/constants/routes.js`: Định nghĩa toàn bộ endpoint URL tập trung.
3. **Sinh Validators & Helpers**:
   - `utils/helpers/validators.js`: Các hàm kiểm tra `isLettersAndSpacesOnly`, `isPositiveNumber`, `isValidEmail`, `isValidUrl`...
   - `utils/helpers/hbsHelpers.js`: Các helper Handlebars (`formatDate`, so sánh `eq`, `gt`, `lt`, format tiền tệ...).
4. **Sinh Middlewares**:
   - `middlewares/errorHandler.js`: Bắt lỗi tập trung, render trang lỗi hoặc trả JSON.
   - `middlewares/authPage.js`: **Sinh code độc quyền theo `authMode`**:
     - _Session_: Chỉ kiểm tra `req.session.user` (không import JWT).
     - _Cookie_: Đọc và giải mã `req.cookies.token`.
     - _LocalStorage_: Đọc `Authorization: Bearer <token>` và cookie dự phòng.
   - `middlewares/authJWT.js`: Bảo vệ các REST API qua Header `Authorization: Bearer <token>`.
5. **Sinh Models (`models/*.js`)**:
   - Mongoose Schema chuẩn kiểu dữ liệu (`String`, `Number`, `Date`, `ObjectId`), thiết lập `enum`, `min`, `max`, `trim`, `unique`.
   - Thiết lập Index và `ref` cho khóa ngoại.
6. **Sinh Repositories (`repositories/*.js`)**:
   - Đóng gói toàn bộ câu lệnh truy vấn MongoDB: `find()`, `findById()`, `create()`, `findByIdAndUpdate()`, `findByIdAndDelete()`, và `.populate()`.
7. **Sinh Services (`services/*.js`)**:
   - **Xử lý toàn bộ logic nghiệp vụ và Validation**:
     - Kiểm tra trường bắt buộc (`required`).
     - Kiểm tra chỉ chứa chữ cái và khoảng trắng (`alpha`).
     - Kiểm tra số dương / số lớn hơn 0 (`positive`).
     - Kiểm tra email hợp lệ, kiểm tra trùng lặp (`unique`).
   - Khi có lỗi, ném ngoại lệ với status từ `utils/constants/errors.js`.
8. **Sinh Controllers (`controllers/*.js`)**:
   - `controllers/auth.js`: **Sinh thuần túy theo `authMode` đã chọn**:
     - Nếu _Session_: Xử lý `req.session.user` và `req.session.destroy()`.
     - Nếu _Cookie_: Ký JWT và gọi `res.cookie('token', ...)`, logout gọi `res.clearCookie()`.
     - Nếu _LocalStorage_: Trả JSON token cho client, logout xóa `localStorage`.
   - `controllers/<Entity>.js`: Điều phối Web Page SSR (danh sách, phân trang, tìm kiếm, thêm, sửa, xóa) và REST API JSON.
9. **Sinh Routes (`routes/*.js`)**:
   - `routes/<entity>.page.js`: Định tuyến giao diện SSR (bảo vệ bởi `authPage`).
   - `routes/<entity>.api.js`: Định tuyến REST API (bảo vệ bởi `authJWT`).
   - `routes/auth.js`: Đăng nhập, đăng xuất.
   - `routes/index.js`: Gắn tất cả router con vào và điều hướng route `/` về trang tương ứng.
10. **Sinh Views HBS (`views/`)**:
    - `views/auth/login.hbs`: Form đăng nhập (chỉ chèn script `localStorage` nếu chọn mode LocalStorage).
    - `views/<entity>/list.hbs` & `cards.hbs`: Bảng dữ liệu / Card danh sách có nút Search, Filter, Sort, Pagination.
    - `views/<entity>/add.hbs` & `edit.hbs`: Form nhập liệu có select box động đổ dữ liệu khóa ngoại từ Service.
    - `views/<entity>/detail.hbs`: Xem chi tiết bản ghi.
    - `views/partials/`: Header, Navbar hiển thị thông tin user đăng nhập, Footer tích hợp Modal xác nhận xóa an toàn.
11. **Cấu hình App (`app.js` & `bin/www`)**:
    - Ghép nối middleware Express, cookie-parser, hbs, static folder.
    - **Chỉ kích hoạt `express-session` khi bạn chọn mode `session`**.

---

#### 5. Bước 5: Khởi tạo Database mẫu & Hoàn tất

1. File tạm `.provision_db.js` kết nối vào MongoDB:
   - Mã hóa mật khẩu tài khoản mặc định bằng `bcryptjs` (User: `admin` / Password: `123456`).
   - Thêm tài khoản quản trị vào collection.
   - Tạo sẵn 3-5 bản ghi mẫu cho các bảng độc lập và bảng chính để khi chạy lên là có sẵn dữ liệu test ngay.
2. Tự động dọn dẹp (xóa các file tạm `.generator_config.json`, `.build_project.js`, `.provision_db.js`).
3. In ra thông báo thành công cùng hướng dẫn khởi động:
   ```bash
   cd <PROJECT_NAME>
   npm run dev
   ```

Toàn bộ quy trình này diễn ra hoàn toàn tự động trong khoảng 5 - 10 giây!
