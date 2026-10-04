import Product from "../models/products.js";
import Supplier from "../models/suppliers.js";

export const getAdminProducts = async (req, res, next) => {
  try {
    const products = await Product.find()
      .populate("supplier")
      .sort({ createdAt: -1 });
    const suppliers = await Supplier.find().sort({ name: 1 });

    const message = req.session.message || req.query.message || null;
    const error = req.session.error || req.query.error || null;
    delete req.session.message;
    delete req.session.error;

    res.render("admin/products", {
      products,
      suppliers,
      manager: req.session.manager,
      message,
      error,
      showAddModal: req.query.showAddModal === "true",
      formData: {},
    });
  } catch (error) {
    next(error);
  }
};

export const postCreateProduct = async (req, res) => {
  const { name, category, price, stock, isActive, supplier, tags } = req.body;
  try {
    const tagArray = tags
      ? tags
          .split(",")
          .map((t) => t.trim())
          .filter((t) => t.length > 0)
      : [];

    const activeStatus =
      isActive === "true" || isActive === "on" || isActive === true;

    await Product.create({
      name: name ? name.trim() : "",
      category: category ? category.trim() : "",
      price: Number(price),
      stock: Number(stock) || 0,
      isActive: activeStatus,
      supplier,
      tags: tagArray,
    });

    req.session.message = "Product added successfully!";
    return res.redirect("/admin/products");
  } catch (error) {
    console.error("Create product error:", error);
    try {
      const products = await Product.find()
        .populate("supplier")
        .sort({ createdAt: -1 });
      const suppliers = await Supplier.find().sort({ name: 1 });

      return res.render("admin/products", {
        products,
        suppliers,
        manager: req.session.manager,
        message: null,
        error: "Failed to add product: " + error.message,
        showAddModal: true,
        formData: req.body,
      });
    } catch (e) {
      return res.redirect(
        "/admin/products?error=" +
          encodeURIComponent("Failed to add product: " + error.message) +
          "&showAddModal=true"
      );
    }
  }
};

export const getEditProduct = async (req, res, next) => {
  try {
    const { id } = req.params;
    const product = await Product.findById(id).populate("supplier");
    const suppliers = await Supplier.find().sort({ name: 1 });

    if (!product) {
      return res.redirect("/admin/products?error=Product not found!");
    }

    res.render("admin/edit-product", {
      product,
      suppliers,
      manager: req.session.manager,
      error: req.query.error || null,
    });
  } catch (error) {
    next(error);
  }
};

export const postUpdateProduct = async (req, res) => {
  const { id } = req.params;
  const { name, category, price, stock, isActive, supplier, tags } = req.body;
  try {
    const tagArray = tags
      ? tags
          .split(",")
          .map((t) => t.trim())
          .filter((t) => t.length > 0)
      : [];

    const activeStatus =
      isActive === "true" || isActive === "on" || isActive === true;

    const updated = await Product.findByIdAndUpdate(
      id,
      {
        name: name ? name.trim() : "",
        category: category ? category.trim() : "",
        price: Number(price),
        stock: Number(stock) || 0,
        isActive: activeStatus,
        supplier,
        tags: tagArray,
      },
      { returnDocument: "after" }
    );

    if (!updated) {
      return res.redirect("/admin/products?error=Product not found to update!");
    }

    req.session.message = "Product updated successfully!";
    return res.redirect("/admin/products");
  } catch (error) {
    console.error("Update product error:", error);
    try {
      const suppliers = await Supplier.find().sort({ name: 1 });
      const currentTags = tags
        ? tags.split(",").map((t) => t.trim())
        : [];

      return res.render("admin/edit-product", {
        product: {
          _id: id,
          name,
          category,
          price,
          stock,
          isActive: isActive === "true" || isActive === "on" || isActive === true,
          supplier: { _id: supplier },
          tags: currentTags,
        },
        suppliers,
        manager: req.session.manager,
        error: "Failed to update product: " + error.message,
      });
    } catch (e) {
      return res.redirect(
        `/admin/products/${id}?error=` +
          encodeURIComponent("Failed to update product: " + error.message)
      );
    }
  }
};

export const postDeleteProduct = async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await Product.findByIdAndDelete(id);

    if (!deleted) {
      req.session.error = "Product not found to delete.";
      return res.redirect("/admin/products");
    }

    req.session.message = "Product deleted successfully!";
    return res.redirect("/admin/products");
  } catch (error) {
    console.error("Delete product error:", error);
    req.session.error = "Failed to delete product: " + error.message;
    return res.redirect("/admin/products");
  }
};
