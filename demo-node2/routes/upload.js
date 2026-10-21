var express = require("express");
var router = express.Router();
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const { randomUUID } = require("crypto"); // import crypto module to generate random string for file name
const { singleUpload, multipleUpload } = require("../controllers/upload");

// lưu trên server
const storage = multer.diskStorage({
  // nhận vào 2 biến là destination và file, cb là callback function
  destination: function (req, file, cb) {
    // nói cho nó biết lưu ở đâu
    const uploadDir = path.join(__dirname, "../uploads");
    fs.mkdir(uploadDir, { recursive: true }, (err) => {
      // tạo folder nếu chưa tồn tại
      // nếu có lỗi thì trả về lỗi, nếu không thì trả về đường dẫn uploadDir
      // cb err là lỗi, uploadDir là đường dẫn lưu file
      // cb là hàm của multer, nó sẽ nhận vào 2 tham số là lỗi và đường dẫn lưu file
      cb(err, uploadDir);
    });
  },
  filename: function (req, file, cb) {
    // đặt tên file là tên gốc của file
    // sẽ tạo ra 1 file mới với tên gốc của file, nếu trùng tên thì nó sẽ ghi đè lên file cũ
    const extension = path.extname(file.originalname);
    // const filename = randomUUID() + extension;
    cb(null, `${Date.now()}-${randomUUID()}${extension}`);
  },
});
const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024, file: 1 },
}); // giới hạn dung lượng file upload là 5MB
const uploadMul = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024, file: 10 },
}); // giới hạn dung lượng file upload là 5MB

router.post("/single", upload.single("file"), singleUpload);
router.post("/multiple", uploadMul.array("files"), multipleUpload);
module.exports = router;
