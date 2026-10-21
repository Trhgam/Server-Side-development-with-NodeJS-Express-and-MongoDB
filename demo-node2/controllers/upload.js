async function singleUpload(req, res, next) {
  try {
    console.log("req.file", req.file);
    const { filename } = req.file;
    if (!filename) {
      return res.status(400).json({
        message: "No file uploaded",
      });
    }
    res.status(200).json({
      message: "File uploaded successfully",
      filename: filename,
    });
  } catch (err) {
    next(err);
  }
}

async function multipleUpload(req, res, next) {
  try {
    console.log("req.files", req.files);
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({
        message: "No files uploaded",
      });
    }
    res.status(200).json({
      message: "Files uploaded successfully",
      filenames: req.files.map((file) => file.filename),
    });
  } catch (err) {
    next(err);
  }
}
module.exports = {
  singleUpload,
  multipleUpload,
};
// Dùng common Js cần export function ra mới dùng được nha
