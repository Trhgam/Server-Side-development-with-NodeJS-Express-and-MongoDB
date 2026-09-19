var express = require("express");
var router = express.Router();
const { getUser, createUser } = require("../controllers/user");

// Tại sao chỗ này lại import bằng ngoặc nhọn mà ko pahir mỗi tên thôi
// vì controller có nhiều function nên ko có default, ko có default phải dùng ngoặc nhọn
// nếu controller users dùng default thì nếu có nhiều function thì chỉ export đc 1 hàm duy nhất thôi
const user = [];

const { body, validationResult } = require("express-validator");
const validates = [
  body("name").notEmpty().withMessage("Name is required"),
  body("email").isEmail().withMessage("Invalid email address"),
  (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    next();
  },
];
/* GET users listing. */
// router.get("/", function (req, res, next) {
//   try {
//     res.send("respond with a resource");
//   } catch (err) {
//     console.log(err);
//     next(err);
//   }
// });

router.get("/", getUser);
router.post("/", validates, createUser);

module.exports = router;
