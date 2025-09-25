# From <https://github.com/oddlama/nixos-extra-modules/blob/fda0b80/lib/shift.nix>
let
  lut = builtins.foldl' (l: n: l ++ [ (2 * builtins.elemAt l n) ]) [ 1 ] (builtins.genList (x: x) 62);
  intmin = (-9223372036854775807) - 1;
  intmax = 9223372036854775807;
  left =
    a: b:
    if a >= 64 then
      # It's allowed to shift out all bits
      0
    else if a == 0 then
      b
    else if a < 0 then
      throw "Inverse Left Shift not supported"
    else
      let
        inv = 63 - a;
        mask = if inv == 63 then intmax else (builtins.elemAt lut inv) - 1;
        masked = builtins.bitAnd b mask;
        checker = if inv == 63 then intmin else builtins.elemAt lut inv;
        negate = (builtins.bitAnd b checker) != 0;
        mult = if a == 63 then intmin else builtins.elemAt lut a;
        result = masked * mult;
      in
      if !negate then result else intmin + result;
  logicalRight =
    a: b:
    if a >= 64 then
      0
    else if a == 0 then
      b
    else if a < 0 then
      throw "Inverse right Shift not supported"
    else
      let
        masked = builtins.bitAnd b intmax;
        negate = b < 0;
        # Split division to prevent having to divide by a negative number for
        # shifts of 63 bit
        result = masked / 2 / (builtins.elemAt lut (a - 1));
        inv = 63 - a;
        highest_bit = builtins.elemAt lut inv;
      in
      if !negate then result else result + highest_bit;
  arithmeticRight =
    a: b:
    if a >= 64 then
      if b < 0 then -1 else 0
    else if a == 0 then
      b
    else if a < 0 then
      throw "Inverse right Shift not supported"
    else
      let
        negate = b < 0;
        mask = if a == 63 then intmax else (builtins.elemAt lut a) - 1;
        round_down = negate && (builtins.bitAnd mask b != 0);
        result = b / 2 / (builtins.elemAt lut (a - 1));
      in
      if round_down then result - 1 else result;
in
{
  inherit left logicalRight arithmeticRight;
}
