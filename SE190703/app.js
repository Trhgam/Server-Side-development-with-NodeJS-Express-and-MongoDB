import createError from "http-errors";
import express from "express";
import path from "path";
import { fileURLToPath } from "url";
import cookieParser from "cookie-parser";
import logger from "morgan";
import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.set("port", process.env.PORT || 3000); //
mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => console.log("[MongoDB] Connected Successfully!"))
  .catch((err) => console.error(" [MongoDB] Connection Error:", err));

import indexRouter from "./routes/index.js";
// import usersRouter from "./routes/users.js";
import productsRouter from "./routes/products.js";
import suppliersRouter from "./routes/suppliers.js";



// view engine setup
app.set("views", path.join(__dirname, "views"));
app.set("view engine", "jade");

app.use(logger("dev"));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, "public")));

app.use("/", indexRouter);
// app.use("/users", usersRouter);
app.use("/products", productsRouter);
app.use("/suppliers", suppliersRouter);

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

export default app;
