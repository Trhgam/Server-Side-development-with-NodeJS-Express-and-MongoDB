// require("../models/products"); // must
const productModel = require("../models/products");

async function getProducts(req, res, next) {
  try {
    const products = await productModel.find().lean();
    // render ngay đây
    // đáng lẽ mình phải ../ nhưng do set ngay app nên
    // không cần set ../ mà lấy trực tiếp chỉ cần để tên file thôi
    // setup thêm router để nó biết vô đường dẫn nào
    res.render("products", { products });
  } catch (err) {
    next(err);
  }
}
async function createProducts(req, res, next) {
  try {
    // 1. Lấy dữ liệu từ form / body gửi lên
    const body = {
      title: req.body.title,
    };

    // 2. Thao tác lưu vào MongoDB (dùng .create() hoặc .insertOne())
    await productModel.create(body);

    // 3. Redirect về đường dẫn danh sách sản phẩm
    res.redirect(303, "/products");
  } catch (err) {
    next(err);
  }
}

async function updateProduct(req, res, next) {
  try {
    const { id } = req.params;
    const { title } = req.body;

    // Cập nhật sản phẩm theo id
    await productModel.findByIdAndUpdate(id, { title });

    // Redirect về trang danh sách sản phẩm
    res.redirect("/products");
  } catch (err) {
    next(err);
  }
}
module.exports = {
  getProducts,
  createProducts,
  updateProduct,
};
