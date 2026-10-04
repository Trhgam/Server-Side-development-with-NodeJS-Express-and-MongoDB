import mongoose from "mongoose";

const managerSchema = new mongoose.Schema(
  {
    code: { type: String, required: true },
    pass: { type: String, required: true },
  },
);

export default mongoose.model("Manager", managerSchema, "managers");
