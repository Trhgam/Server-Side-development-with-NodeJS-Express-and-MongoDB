var express = require("express");
var router = express.Router();
const { download } = require("../controllers/download");
router.get("/:filename", download);
module.exports = router;
