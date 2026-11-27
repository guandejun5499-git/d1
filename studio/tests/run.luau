local rules=require("../shared/logic/Rules")
assert(require("./Performance")(rules)==11)
assert(require("./FlightRules")(rules))
print("11 performance combinations and flight rule checks passed")