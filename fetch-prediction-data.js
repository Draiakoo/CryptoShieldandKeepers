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

const input = `${Sday}-${Smonth}-${Syear}`

const MLmodelData = Functions.makeHttpRequest({
  url: `https://cryptoshieldapiv2.netlify.app/api/prediction/${input}`,
})
const [MLResponse] = await Promise.all([MLmodelData])
const result = MLResponse
const HighPricePredict = result.data.predictedPriceHigh * 10**10
const LowPricePredict = result.data.predictedPriceLow * 10**10
const ClosePricePredict = result.data.predictedPriceClose * 10**10
const HighRisk = result.data.riskHigh * 10 ** 10
const LowRisk = result.data.riskLow * 10 ** 10
const CloseRisk = result.data.riskClose * 10 ** 10

return Buffer.concat([Functions.encodeUint256(HighPricePredict), Functions.encodeUint256(LowPricePredict), Functions.encodeUint256(ClosePricePredict), Functions.encodeUint256(HighRisk), Functions.encodeUint256(LowRisk), Functions.encodeUint256(CloseRisk)])