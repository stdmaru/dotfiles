#version 440

// Adapta ícones da bandeja (feitos para painel escuro) ao tema claro, como um
// ícone simbólico: pixels sem saturação viram a cor de texto do tema e a
// luminância deles vira opacidade. O branco fica opaco, o preto (sombras,
// contornos e recortes, como os olhos do Discord) fica transparente e as
// bordas suavizadas continuam nítidas. Pixels coloridos não mudam. `amount`
// vai de 0 (tema escuro, ícone original) a 1 (tema claro).
//
// Recompile depois de editar:
//   /usr/lib/qt6/bin/qsb --qt6 -o trayicon-symbolic.frag.qsb trayicon-symbolic.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float amount;
    vec4 inkColor;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 pixel = texture(source, qt_TexCoord0);
    if (pixel.a <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec3 color = pixel.rgb / pixel.a;
    float high = max(max(color.r, color.g), color.b);
    float low = min(min(color.r, color.g), color.b);
    float saturation = high > 0.0 ? (high - low) / high : 0.0;
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));

    float weight = amount * (1.0 - smoothstep(0.12, 0.35, saturation));
    vec3 result = mix(color, inkColor.rgb, weight);
    float alpha = pixel.a * mix(1.0, luminance, weight);
    fragColor = vec4(result * alpha, alpha) * qt_Opacity;
}
