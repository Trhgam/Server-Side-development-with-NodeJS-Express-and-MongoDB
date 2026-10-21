const path = require("path");

async function download(req, res, next) {
  try {
    const { filename } = req.params;
    const filePath = path.join(__dirname, "../uploads", filename);
    console.log("Dang download file: ", filePath);
    res.download(filePath, filename, (err) => {
      if (err) {
        next(err);
      }
    });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  download,
};
