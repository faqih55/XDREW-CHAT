import SwiftUI

// MARK: - Auth Flow Enum
enum AuthFlow {
    case login
    case register
    case phone
    case otp(verificationID: String, phone: String)
    case forgotPassword
}

// MARK: - Login View
struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var flow: AuthFlow = .login

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.92, green: 0.90, blue: 0.98), Color(red: 0.97, green: 0.95, blue: 1.0)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            // Decorative blobs
            Circle().fill(Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.12))
                .frame(width: 350, height: 350).blur(radius: 80).offset(x: -120, y: -250)
            Circle().fill(Color.purple.opacity(0.08))
                .frame(width: 300, height: 300).blur(radius: 80).offset(x: 150, y: 300)

            switch flow {
            case .login:
                EmailSignInView(flow: $flow)
            case .register:
                EmailRegisterView(flow: $flow)
            case .phone:
                PhoneSignInView(flow: $flow)
            case .otp(let verificationID, let phone):
                OTPVerifyView(verificationID: verificationID, phone: phone, flow: $flow)
            case .forgotPassword:
                ForgotPasswordView(flow: $flow)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: "\(flow)")
    }
}

// MARK: - Email Sign In
struct EmailSignInView: View {
    @Binding var flow: AuthFlow
    @StateObject private var auth = AuthManager.shared

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 60)

                // Logo
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.45, green: 0.35, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 1.0)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                            .shadow(color: Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.4), radius: 20, y: 8)
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    Text("XDREW Chat")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                    Text("Masuk ke akun Anda")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // Form
                VStack(spacing: 16) {
                    AuthTextField(icon: "envelope.fill", placeholder: "Email", text: $email, isSecure: false)
                        .focused($focusedField, equals: .email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)

                    AuthTextField(icon: "lock.fill", placeholder: "Password", text: $password, isSecure: true)
                        .focused($focusedField, equals: .password)

                    HStack {
                        Spacer()
                        Button("Lupa password?") { flow = .forgotPassword }
                            .font(.caption).foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                    }
                }
                .padding(.horizontal, 24)

                // Error
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption).foregroundColor(.red)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                }

                // Sign In Button
                VStack(spacing: 14) {
                    AuthPrimaryButton(title: "Masuk", isLoading: isLoading) {
                        signIn()
                    }
                    .disabled(email.isEmpty || password.isEmpty)
                    .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                    .padding(.horizontal, 24)

                    // Divider
                    HStack {
                        VStack { Divider() }
                        Text("atau").font(.caption).foregroundColor(.gray).padding(.horizontal, 8)
                        VStack { Divider() }
                    }.padding(.horizontal, 24)

                    // Phone Sign In
                    Button(action: { flow = .phone }) {
                        HStack(spacing: 10) {
                            Image(systemName: "phone.fill")
                                .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                            Text("Masuk dengan Nomor Telepon")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                    }
                    .padding(.horizontal, 24)
                }

                // Register CTA
                HStack(spacing: 4) {
                    Text("Belum punya akun?").foregroundColor(.gray).font(.footnote)
                    Button("Daftar sekarang") { flow = .register }
                        .font(.footnote).fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                }

                Spacer().frame(height: 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func signIn() {
        focusedField = nil
        isLoading = true
        errorMessage = ""
        Task {
            do {
                try await auth.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Email Register
struct EmailRegisterView: View {
    @Binding var flow: AuthFlow
    @StateObject private var auth = AuthManager.shared

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @FocusState private var focused: Bool

    var passwordsMatch: Bool { password == confirmPassword && !password.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 50)

                VStack(spacing: 8) {
                    Text("Buat Akun Baru")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                    Text("Bergabung dengan XDREW Chat")
                        .font(.subheadline).foregroundColor(.gray)
                }

                VStack(spacing: 16) {
                    AuthTextField(icon: "envelope.fill", placeholder: "Email", text: $email, isSecure: false)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    AuthTextField(icon: "lock.fill", placeholder: "Password (min 6 karakter)", text: $password, isSecure: true)
                    AuthTextField(icon: "lock.shield.fill", placeholder: "Konfirmasi Password", text: $confirmPassword, isSecure: true)

                    if !confirmPassword.isEmpty && !passwordsMatch {
                        HStack {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                            Text("Password tidak cocok").font(.caption).foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 24)

                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.caption).foregroundColor(.red)
                        .padding(.horizontal, 24).multilineTextAlignment(.center)
                }

                AuthPrimaryButton(title: "Daftar", isLoading: isLoading) {
                    register()
                }
                .disabled(!passwordsMatch || email.isEmpty)
                .opacity(!passwordsMatch || email.isEmpty ? 0.6 : 1)
                .padding(.horizontal, 24)

                Button(action: { flow = .login }) {
                    HStack(spacing: 4) {
                        Text("Sudah punya akun?").foregroundColor(.gray).font(.footnote)
                        Text("Masuk").font(.footnote).fontWeight(.semibold)
                            .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                    }
                }
                Spacer().frame(height: 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func register() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                try await auth.signUp(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Phone Sign In
struct PhoneSignInView: View {
    @Binding var flow: AuthFlow
    @StateObject private var auth = AuthManager.shared

    @State private var phone = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "phone.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                    .shadow(color: Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.3), radius: 12)
                Text("Masuk via Telepon")
                    .font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.black)
                Text("Kami akan mengirim kode OTP ke nomor Anda")
                    .font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
            }

            // Phone input
            HStack(spacing: 12) {
                Text("🇮🇩 +62")
                    .padding(.horizontal, 14).padding(.vertical, 14)
                    .background(Color.white).cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4)
                    .foregroundColor(.black)

                TextField("812 3456 7890", text: $phone)
                    .keyboardType(.phonePad)
                    .foregroundColor(.black)
                    .padding(.horizontal, 14).padding(.vertical, 14)
                    .background(Color.white).cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4)
            }
            .padding(.horizontal, 24)

            if !errorMessage.isEmpty {
                Text(errorMessage).font(.caption).foregroundColor(.red).padding(.horizontal, 24)
            }

            AuthPrimaryButton(title: "Kirim OTP", isLoading: isLoading) {
                sendOTP()
            }
            .disabled(phone.count < 8)
            .opacity(phone.count < 8 ? 0.6 : 1)
            .padding(.horizontal, 24)

            Button(action: { flow = .login }) {
                Label("Kembali ke Login", systemImage: "arrow.left")
                    .font(.footnote).foregroundColor(.gray)
            }

            Spacer()
            Spacer()
        }
    }

    private func sendOTP() {
        isLoading = true
        errorMessage = ""
        let fullPhone = "+62\(phone.replacingOccurrences(of: " ", with: ""))"
        Task {
            do {
                let id = try await auth.sendOTP(to: fullPhone)
                flow = .otp(verificationID: id, phone: fullPhone)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - OTP Verify
struct OTPVerifyView: View {
    let verificationID: String
    let phone: String
    @Binding var flow: AuthFlow
    @StateObject private var auth = AuthManager.shared

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "message.badge.filled.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                Text("Masukkan Kode OTP")
                    .font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.black)
                Text("Kode dikirim ke \(phone)")
                    .font(.subheadline).foregroundColor(.gray)
            }

            // OTP Field
            TextField("• • • • • •", text: $code)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .focused($focused)
                .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                .padding(20)
                .background(Color.white).cornerRadius(16)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                .padding(.horizontal, 40)
                .onChange(of: code) {
                    if code.count == 6 { verify() }
                }

            if !errorMessage.isEmpty {
                Text(errorMessage).font(.caption).foregroundColor(.red)
            }

            AuthPrimaryButton(title: "Verifikasi", isLoading: isLoading) {
                verify()
            }
            .disabled(code.count < 6)
            .opacity(code.count < 6 ? 0.6 : 1)
            .padding(.horizontal, 24)

            Button(action: { flow = .phone }) {
                Label("Ubah Nomor", systemImage: "arrow.left")
                    .font(.footnote).foregroundColor(.gray)
            }

            Spacer()
            Spacer()
        }
        .onAppear { focused = true }
    }

    private func verify() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                try await auth.verifyOTP(verificationID: verificationID, code: code)
            } catch {
                errorMessage = error.localizedDescription
                code = ""
            }
            isLoading = false
        }
    }
}

// MARK: - Forgot Password
struct ForgotPasswordView: View {
    @Binding var flow: AuthFlow
    @StateObject private var auth = AuthManager.shared

    @State private var email = ""
    @State private var isSent = false
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                Text("Reset Password")
                    .font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.black)
                Text("Masukkan email untuk menerima link reset password")
                    .font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            if isSent {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.largeTitle)
                    Text("Email terkirim!").font(.headline).foregroundColor(.black)
                    Text("Periksa inbox email Anda").font(.caption).foregroundColor(.gray)
                }
                .padding()
                .background(Color.green.opacity(0.08))
                .cornerRadius(16)
                .padding(.horizontal, 24)
            } else {
                AuthTextField(icon: "envelope.fill", placeholder: "Email", text: $email, isSecure: false)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 24)

                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.caption).foregroundColor(.red)
                }

                AuthPrimaryButton(title: "Kirim Link Reset", isLoading: isLoading) {
                    reset()
                }
                .disabled(email.isEmpty)
                .opacity(email.isEmpty ? 0.6 : 1)
                .padding(.horizontal, 24)
            }

            Button(action: { flow = .login }) {
                Label("Kembali ke Login", systemImage: "arrow.left")
                    .font(.footnote).foregroundColor(.gray)
            }

            Spacer()
            Spacer()
        }
    }

    private func reset() {
        isLoading = true
        Task {
            do {
                try await auth.resetPassword(email: email)
                isSent = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Shared Components

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.9))
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.black)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }
}

struct AuthPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.9)
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.45, green: 0.35, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 1.0)],
                    startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
            .shadow(color: Color(red: 0.45, green: 0.35, blue: 0.9).opacity(0.4), radius: 12, y: 6)
        }
        .disabled(isLoading)
    }
}
