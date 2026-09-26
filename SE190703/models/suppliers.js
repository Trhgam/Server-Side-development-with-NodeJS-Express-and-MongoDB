import mongoose from "mongoose";

const supplierSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    phone: { type: Number, required: true },
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
