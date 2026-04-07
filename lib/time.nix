let
  monthDays = [
    31
    28
    31
    30
    31
    30
    31
    31
    30
    31
    30
    31
  ];

  isLeapYear = y: (y / 4 * 4 == y) && ((y / 100 * 100 != y) || (y / 400 * 400 == y));

  daysToYear =
    y:
    let
      countLeaps =
        from: to: (to / 4) - (from / 4) - ((to / 100) - (from / 100)) + ((to / 400) - (from / 400));
    in
    (y - 1970) * 365 + countLeaps 1969 (y - 1);

  daysToMonth =
    y: m:
    let
      sum = builtins.foldl' (acc: i: acc + builtins.elemAt monthDays i) 0 (
        builtins.genList (i: i) (m - 1)
      );
    in
    if m > 2 && isLeapYear y then sum + 1 else sum;

  # Fixed: recursively drop leading zeros, but keep at least one digit
  toInt =
    s:
    let
      len = builtins.stringLength s;
    in
    if len <= 1 then
      builtins.fromJSON s
    else if builtins.substring 0 1 s == "0" then
      toInt (builtins.substring 1 (len - 1) s)
    else
      builtins.fromJSON s;

  iso8601ToUnix =
    iso:
    let
      year = toInt (builtins.substring 0 4 iso);
      month = toInt (builtins.substring 5 2 iso);
      day = toInt (builtins.substring 8 2 iso);
      hour = toInt (builtins.substring 11 2 iso);
      min = toInt (builtins.substring 14 2 iso);
      sec = toInt (builtins.substring 17 2 iso);

      totalDays = (daysToYear year) + (daysToMonth year month) + (day - 1);
    in
    totalDays * 86400 + hour * 3600 + min * 60 + sec;

in
{
  inherit iso8601ToUnix;
}
