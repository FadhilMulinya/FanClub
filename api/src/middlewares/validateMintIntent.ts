import { Request, Response, NextFunction } from "express";
import { validatePhoneNumber } from "../utils/validation";

export const validateMintIntent = (req: Request, res: Response, next: NextFunction) => {
  const { amount, phone } = req.body;

  // Validate amount
  if (!amount || isNaN(amount) || Number(amount) <= 0) {
    return res.status(400).json({
      status: "error",
      success: false,
      message: "Invalid amount provided",
      instance: req.originalUrl,
    });
  }

  // Validate phone number format
  if (!validatePhoneNumber(phone)) {
    return res.status(400).json({
      status: "error",
      success: false,
      message: "Invalid phone number format. Use +2547XXXXXXXX or 2547XXXXXXXX",
      instance: req.originalUrl,
    });
  }

  next();
};
