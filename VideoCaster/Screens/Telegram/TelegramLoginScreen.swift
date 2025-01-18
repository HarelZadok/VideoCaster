//
//  TelegramLoginScreen.swift
//  VideoCaster
//
//  Created by Harel Zadok on 15/01/2025.
//


import SwiftUI
import AwesomeEnum
import TDLibKit

let telegramColor = Color(red: 36 / 255, green: 161 / 255, blue: 222 / 255, opacity: 1)

struct TelegramLoginScreen: View {
    private enum Field: Int, CaseIterable {
        case countryCode, phoneNumber, code
    }
    
    @EnvironmentObject var telegramManager: TelegramManager
    
    @State private var phoneNumber = ""
    @State private var countryCode = ""
    @FocusState private var fieldFocus: Field?
    @State private var isButtonDisabled = true
    @State private var isCodeSent = false
    @State private var code = ""

    var body: some View {
        VStack {
            ScrollView {
                Image(
                    uiImage: Awesome.Brand.telegramPlane.asImage(
                        size: 150,
                        color: Color(telegramColor)
                    )
                )
                Text("Sign in to Telegram")
                    .font(.title)
                    .bold()
                    .padding(.bottom)
                Text("Sign in to your Telegram account to cast videos directly from Telegram onto your TV.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.bottom)
                    .padding(.horizontal)
                HStack {
                    TextField("+1", text: $countryCode)
                        .padding(10)
                        .background(isCodeSent ? Color.clear : Color(.secondarySystemBackground))
                        .clipShape(.rect(
                            topLeadingRadius: 20,
                            bottomLeadingRadius: 20,
                            bottomTrailingRadius: 6,
                            topTrailingRadius: 6
                        ))
                        .frame(width: 65, height: 50)
                        .onChange(of: countryCode) { newValue in
                            var value = newValue.filter { $0.isNumber || $0 == "+" }
                            if value.count == 4 {
                                fieldFocus = .phoneNumber
                            }
                            if value.count > 4 {
                                value = String(value.prefix(4))
                            }
                            if !value.starts(with: "+") {
                                value = "+" + value
                            }
                            if value == "+" {
                                value = ""
                            }
                            countryCode = value
                        }
                        .focused($fieldFocus, equals: .countryCode)
                        .keyboardType(.numberPad)
                        .disabled(isCodeSent)
                        .onTapGesture {
                            fieldFocus = .countryCode
                        }
                    TextField("Phone Number", text: $phoneNumber)
                        .focused($fieldFocus, equals: .phoneNumber)
                        .padding(10)
                        .background(isCodeSent ? Color.clear : Color(.secondarySystemBackground))
                        .clipShape(.rect(
                            topLeadingRadius: 6,
                            bottomLeadingRadius: 6,
                            bottomTrailingRadius: 20,
                            topTrailingRadius: 20
                        ))
                        .frame(height: 50)
                        .onChange(of: phoneNumber) { newValue in
                            if newValue.count > 12 {
                                phoneNumber = String(newValue.prefix(12))
                            }
                        }
                        .keyboardType(.numberPad)
                        .disabled(isCodeSent)
                        .onTapGesture {
                            fieldFocus = .phoneNumber
                        }
                }
                .padding(.horizontal, 16)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            fieldFocus = nil
                        }
                    }
                }
                .opacity(isCodeSent ? 0.5 : 1)
                
                if isCodeSent {
                    TextField("Code", text: $code)
                        .focused($fieldFocus, equals: .code)
                        .frame(height: 40)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 16)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 10)
            }
            
            Spacer()
            
            Button(action: {
                if !isCodeSent {
                    Task {
                        await sendCode()
                    }
                }
                else {
                    Task {
                        await verifyCode()
                    }
                }
            }) {
                Text(isCodeSent ? "Continue" : "Send code")
                    .frame(width: 300, height: 50)
                    .background(isButtonDisabled ? .gray : telegramColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.white)
            }
            .disabled(isButtonDisabled)
            .padding(.bottom, 8)
        }
        .onChange(of: countryCode) { _ in
            isButtonDisabled = countryCode.isEmpty || phoneNumber.isEmpty
        }
        .onChange(of: phoneNumber) { _ in
            isButtonDisabled = countryCode.isEmpty || phoneNumber.isEmpty
        }
        .onChange(of: code) { _ in
            if isCodeSent {
                isButtonDisabled = code.isEmpty
            }
        }
        .navigationTitle("Telegram")
    }
        
    
    
    func sendCode() async {
        isCodeSent = true
        isButtonDisabled = true
        fieldFocus = .code
        do {
            let fullNumber = countryCode + phoneNumber
            UserDefaults.standard.set(fullNumber, forKey: "telegramPhoneNumber")
            try await telegramManager.setPhoneNumber(fullNumber)
        } catch {
            print("Error setting phone number: \(error)")
        }
    }
    
    func verifyCode() async {
        do {
            try await telegramManager.sendAuthenticationCode(code)
        } catch {
            print("Error submitting authentication code: \(error)")
        }
    }
}

#Preview {
    TelegramLoginScreen()
}
