import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
struct TypingIndicatorBubble: View {
    let userName: String
    var avatarUrl: String? = nil
    
    @State private var dot1 = false
    @State private var dot2 = false
    @State private var dot3 = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar
            if let avatarUrl = avatarUrl, !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.2))
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.45, green: 0.35, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 1.0)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(userName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            
            // Bubble with dots
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .offset(y: dot1 ? -4 : 0)
                
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .offset(y: dot2 ? -4 : 0)
                
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .offset(y: dot3 ? -4 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(
                RoundedCorner(radius: 16, corners: [.topLeft, .topRight, .bottomRight])
            )
            .shadow(color: Color.black.opacity(0.05), radius: 2)
            .onAppear {
                startAnimation()
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private func startAnimation() {
        let animation = Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true)
        
        withAnimation(animation) {
            dot1 = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(animation) {
                dot2 = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(animation) {
                dot3 = true
            }
        }
    }
}
