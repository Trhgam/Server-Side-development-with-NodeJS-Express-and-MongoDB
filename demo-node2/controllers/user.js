const userModel = require("../models/users");

async function getUser(req, res, next) {
  // phải có next nha
  // do tương tác với db là bất đồng bộ nên phải thêm async bào báo cho js biết
  // và do code async nên phải dùng await để chờ kết quả trả về từ db và thêm try catch

  try {
    const users = await userModel.find().populate("Post"); // thêm populate vào chỗ nãy thì mới ra được nha
    res.json(users);
  } catch (err) {
    next(err);
  }
}
async function createUser(req, res, next) {
  try {
    const body = {
      name: req.body.name,
      email: req.body.email,
    };
    await userModel.insertOne(body);
    res.status(201).json({
      message: "User created successfully haha",
    });
  } catch (err) {
    console.log(err);
    next(err);
  }
}
module.exports = {
  getUser,
  createUser,
};
// Dùng common Js cần export function ra mới dùng được nha
