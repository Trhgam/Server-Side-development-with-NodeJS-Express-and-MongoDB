require("../models/users"); // must
const postModel = require("../models/post");

async function getPosts(req, res, next) {
  try {
    const posts = await postModel.find().populate({
      path: "author",
      select: "name",
    });
    res.json(posts);
  } catch (err) {
    next(err);
  }
}
async function createPost(req, res, next) {
  try {
    const body = {
      title: req.body.title,
      author: req.body.id, // mốt chỗ này có middleware xử lý trả ra cho mình
    };
    await postModel.insertOne(body);
    res.status(201).json({
      message: "Post created successfully haha",
    });
  } catch (err) {
    console.log(err);
    next(err);
  }
}
module.exports = {
  getPosts,
  createPost,
};
// Dùng common Js cần export function ra mới dùng được nha

// Muốn loại bỏ field nào thì trừ sau populate, muốn lấy nào thì  sau , thì thêm field muốn lấy
// Nếu bạn muốn bỏ luôn cả _id (chỉ lấy duy nhất name), bạn có thể thêm dấu -:
// select: "name -_id"
// Nếu bạn muốn lấy tất cả ngoại trừ 1 trường nào đó (ví dụ bỏ email):
// select: "-email";