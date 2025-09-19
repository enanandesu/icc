///|
test {
  let profile1 = parse("./test/sRGB_IEC61966-2-1_black_scaled.icc")
  inspect(
    profile1,
    content=(
      #|{"colorSpace": "RGB", "connectionSpace": "XYZ", "copyright": "Copyright International Color Consortium, 2009", "description": "sRGB IEC61966-2-1 black scaled", "deviceClass": "Monitor", "deviceModelDescription": "IEC 61966-2-1 Default RGB Colour Space - sRGB", "intent": "Perceptual", "version": "2.0.0", "viewingConditionsDescription": "Reference Viewing Condition in IEC 61966-2-1", "whitepoint": "[0.964202880859375, 1, 0.8249053955078125]"}
    ),
  )
  let profile2 = parse("./test/sRGB_ICC_v4_Appearance.icc")
  inspect(
    profile2,
    content=(
      #|{"colorSpace": "RGB", "connectionSpace": "Lab", "copyright": "COPYRIGHT(c) 2010-2016 Fuji Xerox Co., Ltd.", "creator": "FX", "description": "sRGB_ICC_v4_Appearance.icc", "deviceClass": "Monitor", "intent": "Perceptual", "platform": "Microsoft", "version": "4.3.0", "whitepoint": "[0.964202880859375, 1, 0.8249053955078125]"}
    ),
  )
  let profile3 = parse("./test/USWebCoatedSWOP.icc")
  inspect(
    profile3,
    content=(
      #|{"cmm": "Adobe", "colorSpace": "CMYK", "connectionSpace": "Lab", "copyright": "Copyright 2000 Adobe Systems, Inc.", "creator": "Adobe", "description": "U.S. Web Coated (SWOP) v2", "deviceClass": "Printer", "intent": "Perceptual", "manufacturer": "Adobe", "platform": "Apple", "version": "2.1.0", "whitepoint": "[0.708404541015625, 0.7359466552734375, 0.571044921875]"}
    ),
  )
  let profile4 = parse("./test/D65_XYZ.icc")
  inspect(
    profile4,
    content=(
      #|{"cmm": "none", "colorSpace": "RGB", "connectionSpace": "XYZ", "copyright": "Copyright Hewlett Packard, 2004", "creator": "none", "description": "D65 XYZ profile", "deviceClass": "Monitor", "deviceModelDescription": "IEC 61966-2-1 Default RGB Colour Space - sRGB", "intent": "Relative", "manufacturer": "none", "model": "none", "version": "2.4.0", "viewingConditionsDescription": "Reference Viewing Condition in IEC 61966-2-1", "whitepoint": "[0.964202880859375, 1, 0.8249053955078125]"}
    ),
  )
  let profile5 = parse("./test/ILFORD_CANpro-4000_GPGFG_ProPlatin.icc")
  inspect(
    profile5,
    content=(
      #|{"colorSpace": "RGB", "connectionSpace": "Lab", "copyright": "Copyright X-Rite, Inc.", "creator": "XRCM", "description": "ILFORD_CANpro-4000_GPGFG_ProPlatin.icc", "deviceClass": "Printer", "intent": "Perceptual", "platform": "Microsoft", "version": "4.2.0", "whitepoint": "[0.954559326171875, 0.989593505859375, 0.8075714111328125]"}
    ),
  )
  let profile6 = parse("./test/Probev1_ICCv2.icc")
  inspect(
    profile6,
    content=(
      #|{"cmm": "LINO", "colorSpace": "CMYK", "connectionSpace": "Lab", "copyright": "Copyright 2004 International Color Consortium.  All rights reserved.", "creator": "ICC", "description": "Probev1_ICCv2.icc", "deviceClass": "Printer", "intent": "Perceptual", "manufacturer": "ICC", "model": "PAWG", "platform": "Microsoft", "version": "2.0.0", "whitepoint": "[0.75, 0.5, 0.25]"}
    ),
  )
  let profile7 = parse("./test/Probev1_ICCv4.icc")
  inspect(
    profile7,
    content=(
      #|{"cmm": "LINO", "colorSpace": "CMYK", "connectionSpace": "Lab", "copyright": "Copyright 2004 International Color Consortium.  All rights reserved.", "creator": "ICC", "description": "Probev1_ICCv4.icc", "deviceClass": "Printer", "intent": "Perceptual", "manufacturer": "ICC", "model": "PAWG", "platform": "Microsoft", "version": "4.0.0", "whitepoint": "[0.75, 0.5, 0.25]"}
    ),
  )
  ignore(parse("./test/1.icc")) catch {
    e =>
      inspect(
        e,
        content="Failed to parse file ./test/1.icc: ICC profile is too small (expected at least 132 bytes)",
      )
  }
  ignore(parse("./test/random.icc")) catch {
    e =>
      inspect(
        e,
        content="Failed to parse file ./test/random.icc: ICC profile tag table is invalid",
      )
  }
}
