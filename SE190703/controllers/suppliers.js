import mongoose from "mongoose";
import Supplier from "../models/suppliers.js";
import "../models/products.js";

export const getAllSuppliers = async (req, res, next) => {
  try {
    const suppliers = await Supplier.find();
    return res.status(200).json(suppliers);
  } catch (error) {
    return next(error);
  }
};
export const getSupplierById = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid Supplier ID format" });
    }

    const supplier = await Supplier.findById(id).populate("products");

    if (!supplier) {
      return res.status(404).json({ message: "Supplier not found" });
    }

    return res.status(200).json(supplier);
  } catch (error) {
    return next(error);
  }
};

export const createSupplier = async (req, res, next) => {
  try {
    const newSupplier = await Supplier.create(req.body);
    return res.status(201).json({
      message: "Supplier created successfully",
      data: newSupplier,
    });
  } catch (error) {
    return res.status(400).json({ message: error.message });
  }
};
export const updateSupplier = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid Supplier ID format" });
    }

    const updatedSupplier = await Supplier.findByIdAndUpdate(id, req.body, {
      new: true,
      runValidators: true,
    });

    if (!updatedSupplier) {
      return res.status(404).json({ message: "Supplier not found to update" });
    }

    return res.status(200).json({
      message: "Supplier updated successfully",
      data: updatedSupplier,
    });
  } catch (error) {
    return res.status(400).json({ message: error.message });
  }
};


export const deleteSupplier = async (req, res, next) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid Supplier ID format" });
    }

    const deletedSupplier = await Supplier.findByIdAndDelete(id);

    if (!deletedSupplier) {
      return res.status(404).json({ message: "Supplier not found to delete" });
    }

    return res.status(200).json({
      message: "Supplier deleted successfully",
      data: deletedSupplier,
    });
  } catch (error) {
    return next(error);
  }
};