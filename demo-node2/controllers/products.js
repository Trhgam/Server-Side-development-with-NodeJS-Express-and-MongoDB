require("../models/products"); // must
const productModel = require("../models/product");

async function getProducts(req, res, next) {
  try {
    const products = await productModel.find().lean();
    // render ngay đây
    // đáng lẽ mình phải ../ nhưng do set ngay app nên không cần set ../ mà lấy trực tiếp chỉ cần để tên file thôi
    // setup thêm router để nó biết vô đường dẫn nào
    res.render("products");
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getProducts,
};
