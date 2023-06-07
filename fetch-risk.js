var today = new Date()
const [month, day, year] = [today.getMonth() + 1, today.getDate(), today.getFullYear()]

var Sday, Smonth, Syear
if (day < 10) {
  Sday = "0" + day.toString()
} else {
  Sday = day.toString()
}

if (month < 10) {
  Smonth = "0" + month.toString()
} else {
  Smonth = month.toString()
}

Syear = year.toString()

const input = `${Smonth}-${Sday}-${Syear}`

const MLmodelData = Functions.makeHttpRequest({
  url: `https://cryptoshieldapi.netlify.app/api/risk/${input}`,
})
const [MLResponse] = await Promise.all([MLmodelData])
const result = MLResponse
const high = result.data.high * 10 ** 15
const low = result.data.low * 10 ** 15
const close = result.data.close * 10 ** 15

return Buffer.concat([Functions.encodeUint256(high), Functions.encodeUint256(low), Functions.encodeUint256(close)])
