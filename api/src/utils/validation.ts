export const validatePhoneNumber = (phone: string): boolean => {
  const regex = /^(?:\+?254)(?:1|7)\d{8}$/;
  return regex.test(phone);
};
