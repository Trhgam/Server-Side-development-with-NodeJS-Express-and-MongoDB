var createError = require("http-errors");
var express = require("express");
var path = require("path");
var cookieParser = require("cookie-parser");
var logger = require("morgan");
const uploadRouter = require("./routes/upload")
var indexRouter = require("./routes/index");
// var usersRouter = require("./routes/users");
// var postsRouter = require("./routes/posts");
require("dotenv").config(); // this is required
const cors = require("cors");
// trong thực tế phải config để cho origin nào có thể access domain nào vô
const corsOptions = {
  origin: ["http://localhost:5173", "http://localhost:5174"],
  optionsSuccessStatus: 200, // cho trình duyệt cũ
  allowHeaders: ["Content-Type", "Authorization"], // cho phép header Authorization hoặc ko 
};
const mongoose = require("mongoose"); // import mongoose to use it for database connection
//tạo connection
mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => console.log("Connected to MongoDB database"))
  .catch((err) => {
    console.error("Error connecting to MongoDB database", err);
  });

var app = express();
app.set("port", process.env.PORT || 3000); //
// view engine setup

// khác với router path.join ko cần đi trong ra ngoài mà vào thẳng trực tiếp views
// "Express, khi tao gọi res.render(), hãy đi tìm template trong folder views.";
app.set("views", path.join(__dirname, "views"));
// Không dùng jade -> sửa lại dùng ejs
// "Các template của tao sử dụng EJS. Nếu tao không ghi extension thì hiểu là .ejs.";
app.set("view engine", "ejs");
app.use(cors(corsOptions));
app.use(logger("dev"));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, "public")));
app.use("/download", uploadRouter);
app.use("/", indexRouter);
// app.use("/users", usersRouter);
// app.use("/posts", postsRouter); //
// catch 404 and forward to error handler
app.use(function (req, res, next) {
  next(createError(404));
});

// error handler
app.use(function (err, req, res, next) {
  // set locals, only providing error in development
  res.locals.message = err.message;
  res.locals.error = req.app.get("env") === "development" ? err : {};

  // render the error page
  res.status(err.status || 500);
  res.render("error");
});

module.exports = app;

// Passport
// Local          npm i passport-local --save
// OpenID Connect
// OAuth-based strategies
