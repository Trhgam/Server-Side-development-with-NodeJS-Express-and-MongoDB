var express = require("express");
var router = express.Router();
const {
  getProducts,
  createProducts,
  updateProduct,
} = require("../controllers/products");

router.get("/", getProducts);
router.post("/", createProducts);
router.post("/edit/:id", updateProduct);
router.put("/:id", updateProduct);
module.exports = router;
