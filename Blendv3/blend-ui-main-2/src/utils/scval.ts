export function scaleInputToBigInt(input: string, decimals: number): bigint {
  let scaled_input;
  if (input.includes('.')) {
    let [base, decimal] = input.split('.');
    scaled_input = `${base}${decimal}${'0'.repeat(decimals - decimal.length)}`;
  } else {
    scaled_input = `${input}${'0'.repeat(decimals)}`;
  }
  return BigInt(scaled_input);
}

export function bigintToInput(amount: bigint, decimals: number) {
  const divisor = BigInt(10 ** decimals);
  const integerPart = amount / divisor;
  const fractionalPart = amount % divisor;

  let result = integerPart.toString();

  if (fractionalPart > 0) {
    let fractionalStr = fractionalPart.toString().padStart(decimals, '0');
    result += '.' + fractionalStr;
  } else {
    result += '.' + '0'.repeat(decimals);
  }

  // Trim trailing zeros after the decimal point, but keep at least one digit after the decimal
  result = result.replace(/\.?0+$/, '');
  if (!result.includes('.')) {
    result += '.0';
  }

  return result;
}
