import mongoose from "mongoose";
import Product from "../models/products.js";

export const getAllProducts = async (req, res, next) => {
  try {
    const allowedParams = [
      "category",
      "minPrice",
      "maxPrice",
      "tags",
      "search",
      "name",
      "order",
      "sort",
      "page",
      "limit",
    ];

    const invalidParams = Object.keys(req.query).filter(
      (param) => !allowedParams.includes(param)
    );

    if (invalidParams.length > 0) {
      return res.status(400).json({
        message: `Invalid query parameter(s): ${invalidParams.join(", ")}. Allowed parameters are: ${allowedParams.join(", ")}`,
      });
    }

    const {
      category,
      minPrice,
      maxPrice,
      tags,
      search,
      name,
      order,
      sort,
      page = 1,
      limit = 3,
    } = req.query;

    if (minPrice !== undefined && isNaN(Number(minPrice))) {
      return res.status(400).json({ message: "minPrice must be a valid number" });
    }
    if (maxPrice !== undefined && isNaN(Number(maxPrice))) {
      return res.status(400).json({ message: "maxPrice must be a valid number" });
    }
    if (order && !["asc", "desc"].includes(order.toLowerCase())) {
      return res.status(400).json({ message: "order must be either 'asc' or 'desc'" });
    }
    if (sort && !["asc", "desc"].includes(sort.toLowerCase())) {
      return res.status(400).json({ message: "sort must be either 'asc' or 'desc'" });
    }
    if (page && (isNaN(Number(page)) || Number(page) <= 0)) {
      return res.status(400).json({ message: "Page must bee a positive number" });
    }
    if (limit && (isNaN(Number(limit)) || Number(limit) <= 0)) {
      return res.status(400).json({ message: "limit must be a positive number" });
    }

    const filter = {};

    if (category) {
      filter.category = category;
    }

    if (minPrice || maxPrice) {
      filter.price = {};
      if (minPrice) filter.price.$gte = Number(minPrice);
      if (maxPrice) filter.price.$lte = Number(maxPrice);
    }

    if (tags) {
      const tagArray = Array.isArray(tags) ? tags : tags.split(",");
      filter.tags = { $in: tagArray };
    }

    const keyword = search || name;
    if (keyword) {
      filter.name = { $regex: keyword, $options: "i" };
    }

    const sortOption = {};
    const sortOrder = order || sort;
    if (sortOrder) {
      sortOption.price = sortOrder.toLowerCase() === "asc" ? 1 : -1;
    }

    const skip = (Number(page) - 1) * Number(limit);

    const products = await Product.find(filter)
      .sort(sortOption)
      .skip(skip)
      .limit(Number(limit));

    return res.status(200).json(products);
  } catch (error) {
    return next(error);
  }
};

export const getProductById = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid Product ID format" });
    }

    const product = await Product.findById(id).populate("supplier", "name");

    if (!product) {
      return res.status(404).json({ message: "Product not found" });
    }

    return res.status(200).json(product);
  } catch (error) {
    return next(error);
  }
};

export const createProduct = async (req, res, next) => {
  try {
    const { name, price, category, tags, supplier } = req.body;

    if (supplier && !mongoose.Types.ObjectId.isValid(supplier)) {
      return res.status(400).json({ message: "Invalid Supplier ID format" });
    }

    const newProduct = await Product.create({
      name,
      price,
      category,
      tags,
      supplier,
    });

    return res.status(201).json({
      message: "Product created successfully",
      data: newProduct,
    });
  } catch (error) {
    return res.status(400).json({ message: error.message });
  }
};

export const updateProduct = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid Product ID format" });
    }

    const updatedProduct = await Product.findByIdAndUpdate(id, req.body, {
      new: true,
      runValidators: true,
    });

    if (!updatedProduct) {
      return res.status(404).json({ message: "Product not found to update" });
    }

    return res.status(200).json({
      message: "Product updated successfully",
      data: updatedProduct,
    });
  } catch (error) {
    return res.status(400).json({ message: error.message });
  }
};

export const deleteProduct = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid Product ID format" });
    }

    const deletedProduct = await Product.findByIdAndDelete(id);

    if (!deletedProduct) {
      return res.status(404).json({ message: "Product not found to delete" });
    }

    return res.status(200).json({
      message: "Product deleted successfully",
      data: deletedProduct,
    });
  } catch (error) {
    return next(error);
  }
};
