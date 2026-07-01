import SwiftUI
import AppKit

extension Color {
    static let cardBackground = Color(NSColor.controlBackgroundColor)
    static let cardBackgroundSoft = Color(NSColor.textBackgroundColor)
    static let panelStroke = Color.primary.opacity(0.08)
}

enum AppBackgroundTone {
    case lavender, mint, peach, sky

    func colors(for scheme: ColorScheme) -> [Color] {
        if scheme == .dark {
            switch self {
            case .lavender: return [Color(red: 0.11, green: 0.09, blue: 0.18),
                                    Color(red: 0.08, green: 0.10, blue: 0.20)]
            case .mint:     return [Color(red: 0.09, green: 0.13, blue: 0.18),
                                    Color(red: 0.08, green: 0.11, blue: 0.16)]
            case .peach:    return [Color(red: 0.16, green: 0.10, blue: 0.12),
                                    Color(red: 0.14, green: 0.10, blue: 0.16)]
            case .sky:      return [Color(red: 0.08, green: 0.12, blue: 0.20),
                                    Color(red: 0.09, green: 0.10, blue: 0.20)]
            }
        } else {
            switch self {
            case .lavender: return [Color(red: 0.97, green: 0.95, blue: 1.00),
                                    Color(red: 0.94, green: 0.97, blue: 1.00)]
            case .mint:     return [Color(red: 0.97, green: 0.97, blue: 1.00),
                                    Color(red: 0.95, green: 0.97, blue: 1.00)]
            case .peach:    return [Color(red: 1.00, green: 0.97, blue: 0.96),
                                    Color(red: 0.99, green: 0.96, blue: 0.99)]
            case .sky:      return [Color(red: 0.97, green: 0.98, blue: 1.00),
                                    Color(red: 0.96, green: 0.96, blue: 1.00)]
            }
        }
    }
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme
    let tone: AppBackgroundTone

    var body: some View {
        LinearGradient(colors: tone.colors(for: scheme),
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

// MARK: - 极光/柔光弥散背景（浅色系 + 大面积模糊彩色光斑）

/// 强制浅色的「柔光弥散」背景：始终浅底 + 四角明亮柔和的粉/橙/蓝/紫光斑。
/// 不跟随系统深色——参考图是纯浅色设计，跟随系统会变脏。
struct AuroraBackground: View {
    var body: some View {
        ZStack {
            // 极浅的暖白底
            Color(red: 0.972, green: 0.976, blue: 0.988).ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    blob(Color(red: 0.99, green: 0.62, blue: 0.78), at: CGPoint(x: w*0.08, y: h*0.68), r: max(w,h)*0.46) // 粉
                    blob(Color(red: 1.00, green: 0.76, blue: 0.52), at: CGPoint(x: w*0.92, y: h*0.82), r: max(w,h)*0.44) // 橙
                    blob(Color(red: 0.62, green: 0.78, blue: 1.00), at: CGPoint(x: w*0.88, y: h*0.06), r: max(w,h)*0.40) // 蓝
                    blob(Color(red: 0.78, green: 0.70, blue: 1.00), at: CGPoint(x: w*0.16, y: h*0.04), r: max(w,h)*0.34) // 紫
                }
                .blur(radius: 100)
                .opacity(0.60)
            }
            .ignoresSafeArea()
        }
    }

    private func blob(_ color: Color, at p: CGPoint, r: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color, color.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: r))
            .frame(width: r*2, height: r*2)
            .position(p)
    }
}

// MARK: - 毛玻璃卡片修饰符（浅色·白玻璃）

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 18
    func body(content: Content) -> some View {
        content
            // 用半透明纯白而非 .ultraThinMaterial —— material 在深色环境会发黑；
            // 这里强制白玻璃，保证参考图那种干净通透感。
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.62))
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.70), lineWidth: 1)
            )
            .shadow(color: Color(red: 0.5, green: 0.45, blue: 0.6).opacity(0.10), radius: 20, x: 0, y: 10)
    }
}

extension View {
    /// 白色毛玻璃卡片外观（通透 + 高光描边 + 柔和彩色阴影）。
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
