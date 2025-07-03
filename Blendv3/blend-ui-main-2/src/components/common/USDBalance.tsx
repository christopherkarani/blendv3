import { FixedMath } from '@blend-capital/blend-sdk';
import { Tooltip } from '@mui/material';
import { toBalance } from '../../utils/formatter';

export function toUSDBalance(
  price: number | undefined,
  amount: number | bigint | undefined,
  decimals: number = 7
): string | JSX.Element {
  if (amount == undefined) {
    return '$--';
  }
  if (price == undefined) {
    return (
      <Tooltip
        title="Asset price is not currently available."
        placement="top"
        enterTouchDelay={0}
        enterDelay={500}
        leaveTouchDelay={3000}
      >
        <span style={{ cursor: 'help' }}>{`$--`}</span>
      </Tooltip>
    );
  }
  let amount_as_float: number;
  if (typeof amount === 'bigint') {
    amount_as_float = FixedMath.toFloat(amount, decimals);
  } else {
    amount_as_float = amount;
  }
  return `$${toBalance(amount_as_float * price)}`;
}
