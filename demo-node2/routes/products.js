var express = require("express");
var router = express.Router();
const { getProducts } = require("../controllers/products");

router.get("/", getProducts);

module.exports = router;
