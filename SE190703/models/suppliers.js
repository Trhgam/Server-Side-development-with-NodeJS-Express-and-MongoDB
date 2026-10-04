import mongoose from "mongoose";

const supplierSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, "Supplier name is required"],
      trim: true,
    },
    email: {
      type: String,
      trim: true,
      lowercase: true,
    },
    phone: {
      type: String,
      required: [true, "Supplier phone is required"],
      trim: true,
    },
    address: {
      type: String,
      trim: true,
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
    id: false,
  },
);
//  virtuals
supplierSchema.virtual("products", {
  ref: "Product",
  localField: "_id",
  foreignField: "supplier",
});

export default mongoose.model("Supplier", supplierSchema);
