import express from "express";
import {
  getAdminProducts,
  postCreateProduct,
  getEditProduct,
  postUpdateProduct,
  postDeleteProduct,
} from "../controllers/adminProducts.js";
import { requireLogin } from "../middlewares/auth.js";

const router = express.Router();

// router.use(requireLogin);

router.get("/", getAdminProducts);
router.post("/create", postCreateProduct);
router.post("/", postCreateProduct);
router.post("/delete/:id", postDeleteProduct);
router.get("/delete/:id", postDeleteProduct);
router.get("/:id", getEditProduct);
router.post("/:id", postUpdateProduct);
router.post("/edit/:id", postUpdateProduct);

export default router;
