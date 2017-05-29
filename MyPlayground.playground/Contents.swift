//: Playground - noun: a place where people can play

import Cocoa

let mode = "LSB"
let value = -2800
let filterHigh = -100
let filterLow = -2800
let cwPitch = 600
let rttyMark = 1_000
let rttyShift = 2_000

var newValue = (value > filterHigh - 10 ? filterHigh - 10 : value)

switch mode {
    
case "LSB", "DIGL":
    newValue = (newValue < -12_000 ? -12_000 : newValue)
    
case "CW":
    newValue = (newValue < -12_000 - cwPitch ? -12_000 - cwPitch : newValue)
    
case "RTTY":
    newValue = (newValue < -12_000 + rttyMark ? -12_000 + rttyMark : newValue)
    newValue = (newValue > -50 + rttyShift ? -50 + rttyShift : newValue)
    
case "DSB", "AM", "SAM", "FM", "NFM", "DFM", "DSTR":
    newValue = (newValue < -12_000 ? -12_000 : newValue)
    newValue = (newValue > -10 ? -10 : newValue)
    
case "USB", "DIGU", "FDV":
    newValue = (newValue < 0 ? 0 : newValue)
    
default:
    newValue = (newValue < 0 ? 0 : newValue)
}
newValue


