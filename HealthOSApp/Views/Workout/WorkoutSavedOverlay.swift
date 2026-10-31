import SwiftUI

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.25, y: rect.height * 0.50))
        path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.68))
        path.addLine(to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.33))
        return path
    }
}

struct WorkoutSavedOverlay: View {
    @Binding var isPresented: Bool

    @State private var circleTrim: CGFloat = 0
    @State private var checkTrim: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var textScale: CGFloat = 0.8

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: circleTrim)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    CheckmarkShape()
                        .trim(from: 0, to: checkTrim)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .frame(width: 80, height: 80)
                }

                Text("Workout Saved!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .opacity(textOpacity)
                    .scaleEffect(textScale)
            }
        }
        .onAppear {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif

            withAnimation(.easeInOut(duration: 0.5)) {
                circleTrim = 1.0
            }
            withAnimation(.easeInOut(duration: 0.4).delay(0.3)) {
                checkTrim = 1.0
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
                textOpacity = 1.0
                textScale = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPresented = false
                }
            }
        }
    }
}
