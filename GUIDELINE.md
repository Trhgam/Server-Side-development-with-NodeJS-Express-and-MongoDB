# 📘 HƯỚNG DẪN CHI TIẾT LÀM BÀI SDN302 (CHUẨN ES MODULE)
> **Mục tiêu:** Hướng dẫn từng bước từ lúc gõ lệnh tạo project bằng `express-generator`, chuyển đổi sang **ES Module (`import`/`export`)**, kết nối MongoDB bằng Mongoose, nạp biến môi trường bằng `dotenv`, xây dựng CRUD 2 Schema có liên kết (ObjectId `ref`) và lọc theo Query String (`?category=...`).

---

## 📌 QUY TRÌNH 7 BƯỚC "CẦM TAY CHỈ VIỆC"
1. [Bước 1: Tạo project & Cài đặt thư viện](#bước-1-tạo-project--cài-đặt-thư-viện)
2. [Bước 2: Sửa file `package.json` (Bật ES Module)](#bước-2-sửa-file-packagejson-bật-es-module)
3. [Bước 3: Tạo file `.env` (Port & MongoDB URI)](#bước-3-tạo-file-env)
4. [Bước 4: Sửa file `app.js` (Chi tiết từng dòng cần thay thế)](#bước-4-sửa-file-appjs)
5. [Bước 5: Sửa file `bin/www` và các route mặc định](#bước-5-sửa-file-binwww-và-các-route-mặc-định)
6. [Bước 6: Tạo Models, Controllers & Routes cho bài thi](#bước-6-tạo-models-controllers--routes)
7. [Bước 7: Chạy dự án & Hướng dẫn Test Postman](#bước-7-chạy-dự-án--test-postman)

---

## BƯỚC 1: TẠO PROJECT & CÀI ĐẶT THƯ VIỆN

Mở Terminal tại thư mục bạn muốn làm bài và chạy 3 lệnh sau:

```bash
# 1. Tạo project bằng express-generator (ví dụ đặt tên là test1)
npx express-generator test1

# 2. Đi vào thư mục vừa tạo
cd test1

# 3. Cài các package mặc định của generator
npm install

# 4. Cài thêm dotenv và mongoose (bắt buộc theo đề bài)
npm install dotenv mongoose
```

---

## BƯỚC 2: SỬA FILE `package.json` (BẬT ES MODULE)

Mở file `package.json` lên:
- Thêm dòng `"type": "module"` vào (ngay bên dưới `"private": true`).

```json
{
  "name": "test1",
  "version": "0.0.0",
  "private": true,
  "type": "module", 
  "scripts": {
    "start": "node ./bin/www"
  },
  "dependencies": {
    "cookie-parser": "~1.4.4",
    "debug": "~2.6.9",
    "dotenv": "^16.4.5",
    "express": "~4.16.1",
    "http-errors": "~1.6.3",
    "jade": "~1.11.0",
    "mongoose": "^8.0.0",
    "morgan": "~1.9.1"
  }
}
```

---

## BƯỚC 3: TẠO FILE `.env`

Tạo file mới tên là `.env` ngay tại **thư mục gốc** (cùng cấp với `package.json` và `app.js`):

```env
PORT=5000
MONGODB_URI=mongodb://127.0.0.1:27017/sdn302_exam
```
*(Nếu đề bài yêu cầu cổng khác hoặc tên database khác, bạn chỉ cần sửa giá trị ở đây).*

---

## BƯỚC 4: SỬA FILE `app.js`

> 💡 **BẢNG SO SÁNH: GENERATOR CŨ (COMMONJS) VS MỚI (ES MODULE)**
> 
> | Điểm khác biệt | Code cũ do Generator sinh ra | Code mới cần sửa lại |
> | :--- | :--- | :--- |
> | **Cú pháp import** | `var express = require('express');` | `import express from 'express';` |
> | **Đường dẫn import file**| `require('./routes/index')` | `import indexRouter from './routes/index.js'` *(Bắt buộc có `.js`)* |
> | **Biến `__dirname`** | Có sẵn tự động | **Không có sẵn**, phải tạo từ `fileURLToPath` |
> | **Nạp `.env`** | Chưa có | Phải thêm `import dotenv from 'dotenv'; dotenv.config();` |
> | **Connect MongoDB** | Chưa có | Phải thêm `mongoose.connect(process.env.MONGODB_URI)...` |
> | **Xuất module** | `module.exports = app;` | `export default app;` |

👉 **HÀNH ĐỘNG:** Bạn mở file `app.js` lên, **XÓA HẾT NỘI DUNG CŨ** và dán toàn bộ đoạn code chuẩn dưới đây vào:

### 📄 Nội dung chuẩn của `app.js`:
```javascript
import createError from 'http-errors';
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import cookieParser from 'cookie-parser';
import logger from 'morgan';
import mongoose from 'mongoose';
import dotenv from 'dotenv';

// 1. NẠP FILE .ENV (Bắt buộc để đọc được MONGODB_URI và PORT)
dotenv.config();

// 2. TẠO BIẾN __dirname (Bắt buộc vì ES Module không có sẵn __dirname)
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 3. KẾT NỐI MONGODB BẰNG MONGOOSE
mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => console.log('>>> [MongoDB] Connected Successfully!'))
  .catch((err) => console.error('>>> [MongoDB] Connection Error:', err));

// 4. IMPORT ROUTERS (Chú ý: BẮT BUỘC PHẢI CÓ ĐUÔI .js)
import indexRouter from './routes/index.js';
import usersRouter from './routes/users.js';
import categoriesRouter from './routes/categories.js';
import productsRouter from './routes/products.js';

var app = express();

// View engine setup (giữ nguyên mặc định của generator)
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'jade');

app.use(logger('dev'));
app.use(express.json()); // QUAN TRỌNG: để đọc req.body từ JSON (Postman)
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

// 5. ĐĂNG KÝ ROUTERS
app.use('/', indexRouter);
app.use('/users', usersRouter);
app.use('/categories', categoriesRouter);
app.use('/products', productsRouter);

// Catch 404 and forward to error handler
app.use(function (req, res, next) {
  next(createError(404));
});

// Error handler
app.use(function (err, req, res, next) {
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};

  res.status(err.status || 500);
  res.render('error');
});

// 6. XUẤT APP (Dùng export default, TUYỆT ĐỐI KHÔNG dùng module.exports)
export default app;
```

---

## BƯỚC 5: SỬA FILE `bin/www` VÀ CÁC ROUTE MẶC ĐỊNH

Vì ta đã bật `"type": "module"`, tất cả các file có sẵn do Generator tạo ra nếu còn dùng `require()` sẽ làm server văng lỗi. Ta cần sửa nhanh 3 file này:

### 1. Sửa file `bin/www`:
Mở file `bin/www`, **chỉ cần đổi 3 dòng đầu tiên**:

- **Cũ (Generator):**
  ```javascript
  var app = require('../app');
  var debug = require('debug')('test1:server');
  var http = require('http');
  ```
- **Đổi thành:**
  ```javascript
  import app from '../app.js'; // Nhớ phải có đuôi .js
  import debugLib from 'debug';
  import http from 'http';
  const debug = debugLib('test1:server');
  ```
*(Toàn bộ các dòng phía sau giữ nguyên 100%).*

---

### 2. Sửa file `routes/index.js`:
Mở file `routes/index.js`, thay thế toàn bộ bằng:
```javascript
import express from 'express';
const router = express.Router();

router.get('/', function(req, res, next) {
  res.render('index', { title: 'Express' });
});

export default router;
```

---

### 3. Sửa file `routes/users.js`:
Mở file `routes/users.js`, thay thế toàn bộ bằng:
```javascript
import express from 'express';
const router = express.Router();

router.get('/', function(req, res, next) {
  res.send('respond with a resource');
});

export default router;
```

---

## BƯỚC 6: TẠO MODELS, CONTROLLERS & ROUTES

Giả sử đề bài thi cho 2 Schemas:
- **Category** (Bảng 1): `name`, `description`
- **Product** (Bảng N): `name`, `price`, `description`, `category` (ObjectId tham chiếu `Category`)

Tạo 2 thư mục mới: `models/` và `controllers/`.

---

### 📄 1. Model: `models/Category.js`
```javascript
import mongoose from 'mongoose';

const categorySchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Category name is required'],
      trim: true
    },
    description: {
      type: String,
      trim: true
    }
  },
  { 
    timestamps: true 
  }
);

export default mongoose.model('Category', categorySchema);
```

---

### 📄 2. Model: `models/Product.js`
```javascript
import mongoose from 'mongoose';

const productSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Product name is required'],
      trim: true
    },
    price: {
      type: Number,
      required: [true, 'Price is required'],
      min: 0
    },
    description: {
      type: String
    },
    // Khóa ngoại liên kết tới bảng Category
    category: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Category', // Tên model phải khớp chính xác với Category.js
      required: [true, 'Product must belong to a category']
    }
  },
  { 
    timestamps: true 
  }
);

export default mongoose.model('Product', productSchema);
```

---

### 📄 3. Controller: `controllers/productController.js`
Gồm đầy đủ 5 chức năng CRUD + Query String `category` + Populate:

```javascript
import mongoose from 'mongoose';
import Product from '../models/Product.js'; // Nhớ có .js

// 1. GET ALL (Có lọc theo Query String: ?category=... và populate category)
export const getAllProducts = async (req, res, next) => {
  try {
    const { category } = req.query; // Nhận category từ query string: /products?category=...
    const filter = {};

    // Nếu người dùng có truyền param category
    if (category) {
      filter.category = category;
    }

    // find(filter): nếu không có param thì filter={}, lấy toàn bộ
    const products = await Product.find(filter)
      .populate('category', 'name description') // Nạp thông tin bảng category
      .sort({ createdAt: -1 });

    return res.status(200).json(products);
  } catch (error) {
    return next(error);
  }
};

// 2. GET PRODUCT BY ID (/products/:id)
export const getProductById = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Kiểm tra định dạng ObjectId hợp lệ để tránh crash server
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'Invalid Product ID format' });
    }

    const product = await Product.findById(id).populate('category', 'name description');

    if (!product) {
      return res.status(404).json({ message: 'Product not found' });
    }

    return res.status(200).json(product);
  } catch (error) {
    return next(error);
  }
};

// 3. CREATE PRODUCT (POST /products)
export const createProduct = async (req, res, next) => {
  try {
    const { name, price, description, category } = req.body;

    // Validate ID của category nếu có gửi lên
    if (category && !mongoose.Types.ObjectId.isValid(category)) {
      return res.status(400).json({ message: 'Invalid Category ID format' });
    }

    const newProduct = await Product.create({
      name,
      price,
      description,
      category
    });

    return res.status(201).json({
      message: 'Product created successfully',
      data: newProduct
    });
  } catch (error) {
    return res.status(400).json({ message: error.message });
  }
};

// 4. UPDATE PRODUCT (PUT /products/:id)
export const updateProduct = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'Invalid Product ID format' });
    }

    // new: true để trả về dữ liệu mới; runValidators: true để kiểm tra ràng buộc schema
    const updatedProduct = await Product.findByIdAndUpdate(
      id,
      req.body,
      { new: true, runValidators: true }
    );

    if (!updatedProduct) {
      return res.status(404).json({ message: 'Product not found to update' });
    }

    return res.status(200).json({
      message: 'Product updated successfully',
      data: updatedProduct
    });
  } catch (error) {
    return res.status(400).json({ message: error.message });
  }
};

// 5. DELETE PRODUCT (DELETE /products/:id)
export const deleteProduct = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'Invalid Product ID format' });
    }

    const deletedProduct = await Product.findByIdAndDelete(id);

    if (!deletedProduct) {
      return res.status(404).json({ message: 'Product not found to delete' });
    }

    return res.status(200).json({
      message: 'Product deleted successfully',
      data: deletedProduct
    });
  } catch (error) {
    return next(error);
  }
};
```

---

### 📄 4. Controller: `controllers/categoryController.js` (Tạo danh mục để lấy ID test)
```javascript
import Category from '../models/Category.js';

export const getCategories = async (req, res, next) => {
  try {
    const categories = await Category.find();
    return res.status(200).json(categories);
  } catch (error) {
    return next(error);
  }
};

export const createCategory = async (req, res, next) => {
  try {
    const newCategory = await Category.create(req.body);
    return res.status(201).json({
      message: 'Category created successfully',
      data: newCategory
    });
  } catch (error) {
    return res.status(400).json({ message: error.message });
  }
};
```

---

### 📄 5. Route: `routes/products.js`
```javascript
import express from 'express';
import {
  getAllProducts,
  getProductById,
  createProduct,
  updateProduct,
  deleteProduct
} from '../controllers/productController.js';

const router = express.Router();

router.get('/', getAllProducts);         // GET /products HOẶC /products?category=...
router.get('/:id', getProductById);      // GET /products/:id
router.post('/', createProduct);         // POST /products
router.put('/:id', updateProduct);       // PUT /products/:id
router.delete('/:id', deleteProduct);    // DELETE /products/:id

export default router;
```

---

### 📄 6. Route: `routes/categories.js`
```javascript
import express from 'express';
import { getCategories, createCategory } from '../controllers/categoryController.js';

const router = express.Router();

router.get('/', getCategories);
router.post('/', createCategory);

export default router;
```

---

## BƯỚC 7: CHẠY DỰ ÁN & TEST POSTMAN

Chạy lệnh start server:
```bash
npm start
```
Nếu console xuất hiện dòng:
```text
>>> [MongoDB] Connected Successfully!
```
Nghĩa là server đã kết nối Database và chạy hoàn hảo!

### 🧪 Trình tự gửi Request trên Postman / Thunder Client:

1. **Tạo Category:**
   - `POST http://localhost:5000/categories`
   - Body (JSON): `{"name": "Laptop", "description": "Thiết bị di động"}`
   - ➡️ **Copy mã `_id` vừa nhận được.**

2. **Tạo Product (gắn ID category vừa copy):**
   - `POST http://localhost:5000/products`
   - Body (JSON):
     ```json
     {
       "name": "MacBook Air M2",
       "price": 1200,
       "description": "Bản 256GB",
       "category": "<dán _id Category vào đây>"
     }
     ```

3. **Lấy tất cả Products:**
   - `GET http://localhost:5000/products`

4. **Lọc Product theo Category bằng Query String (Yêu cầu đề thi):**
   - `GET http://localhost:5000/products?category=<_id_cua_category>`

5. **Lấy chi tiết 1 Product:**
   - `GET http://localhost:5000/products/<_id_cua_product>`

6. **Cập nhật Product:**
   - `PUT http://localhost:5000/products/<_id_cua_product>`
   - Body (JSON): `{"price": 1100}`

7. **Xóa Product:**
   - `DELETE http://localhost:5000/products/<_id_cua_product>`
