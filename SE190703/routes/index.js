import express from "express";
import productsRouter from "./products.js";
import suppliersRouter from "./suppliers.js";
import authRouter from "./auth.js";
import adminProductsRouter from "./adminProducts.js";
import checkCode from "../middlewares/checkCode.js";


const router = express.Router();

router.get("/", (req, res) => {
  res.redirect("/auth/view");
});

router.use("/products", checkCode, productsRouter);
router.use("/suppliers", suppliersRouter);
router.use("/auth", authRouter);
router.use("/admin/products", adminProductsRouter);

export default router;
