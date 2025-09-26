use rand::seq::SliceRandom;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Avatar {
    pub style: AvatarStyle,
    pub color: String,
    pub background: String,
    pub url: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AvatarStyle {
    Initials,
    Animal,
    Abstract,
    Gradient,
    Pattern,
}

pub struct AvatarService;

impl AvatarService {
    // 预定义的动物头像集合
    const ANIMAL_AVATARS: &'static [&'static str] = &[
        "bear", "cat", "dog", "fox", "koala", "lion", "mouse", "owl", 
        "panda", "penguin", "pig", "rabbit", "tiger", "wolf", "elephant",
        "giraffe", "hippo", "monkey", "zebra", "deer", "squirrel", "bird"
    ];
    
    // 预定义的颜色主题
    const COLOR_THEMES: &'static [(&'static str, &'static str)] = &[
        ("#FF6B6B", "#FFE3E3"), // 红色系
        ("#4ECDC4", "#E3FFF8"), // 青色系
        ("#45B7D1", "#E3F4F8"), // 蓝色系
        ("#FFA07A", "#FFE5DC"), // 橙色系
        ("#98D8C8", "#E8F5F2"), // 薄荷绿
        ("#F7DC6F", "#FFF9E6"), // 黄色系
        ("#BB8FCE", "#F4ECFA"), // 紫色系
        ("#85C88A", "#EBF5EC"), // 绿色系
        ("#F8B739", "#FFF4E0"), // 金色系
        ("#5DADE2", "#E6F3FA"), // 天蓝色
        ("#EC7063", "#FDEAEA"), // 珊瑚色
        ("#A569BD", "#F2E9F6"), // 兰花紫
    ];
    
    // 预定义的抽象图案
    const ABSTRACT_PATTERNS: &'static [&'static str] = &[
        "circles", "squares", "triangles", "hexagons", "waves", 
        "dots", "stripes", "zigzag", "spiral", "grid", "diamonds"
    ];
    
    /// 为新用户生成随机头像
    pub fn generate_random_avatar(user_name: &str, user_email: &str) -> Avatar {
        let mut rng = rand::thread_rng();
        
        // 随机选择头像风格
        let style = match rand::random::<u8>() % 4 {
            0 => AvatarStyle::Initials,
            1 => AvatarStyle::Animal,
            2 => AvatarStyle::Abstract,
            3 => AvatarStyle::Gradient,
            _ => AvatarStyle::Pattern,
        };
        
        // 随机选择颜色主题
        let (color, background) = Self::COLOR_THEMES
            .choose(&mut rng)
            .unwrap_or(&("#4ECDC4", "#E3FFF8"));
        
        // 根据风格生成URL
        let url = match style {
            AvatarStyle::Initials => {
                // 使用用户名首字母
                let initials = Self::get_initials(user_name);
                format!("https://ui-avatars.com/api/?name={}&background={}&color={}&size=256", 
                    initials, 
                    &background[1..], // 去掉#号
                    &color[1..]
                )
            },
            AvatarStyle::Animal => {
                // 使用动物头像
                let animal = Self::ANIMAL_AVATARS
                    .choose(&mut rng)
                    .unwrap_or(&"panda");
                format!("https://api.dicebear.com/7.x/animalz/svg?seed={}&backgroundColor={}", 
                    animal,
                    &background[1..]
                )
            },
            AvatarStyle::Abstract => {
                // 使用抽象图案
                let pattern = Self::ABSTRACT_PATTERNS
                    .choose(&mut rng)
                    .unwrap_or(&"circles");
                format!("https://api.dicebear.com/7.x/shapes/svg?seed={}&backgroundColor={}", 
                    pattern,
                    &background[1..]
                )
            },
            AvatarStyle::Gradient => {
                // 使用渐变头像
                format!("https://source.boringavatars.com/beam/256/{}?colors={},{}", 
                    user_email,
                    &color[1..],
                    &background[1..]
                )
            },
            AvatarStyle::Pattern => {
                // 使用图案头像
                format!("https://api.dicebear.com/7.x/identicon/svg?seed={}&backgroundColor={}", 
                    user_email,
                    &background[1..]
                )
            },
        };
        
        Avatar {
            style,
            color: color.to_string(),
            background: background.to_string(),
            url,
        }
    }
    
    /// 根据用户ID生成确定性头像（同一ID总是生成相同头像）
    pub fn generate_deterministic_avatar(user_id: &str, user_name: &str) -> Avatar {
        // 使用用户ID的哈希值作为种子
        let hash = Self::simple_hash(user_id);
        let theme_index = (hash % Self::COLOR_THEMES.len() as u32) as usize;
        let (color, background) = Self::COLOR_THEMES[theme_index];
        
        // 基于哈希选择风格
        let style = match hash % 5 {
            0 => AvatarStyle::Initials,
            1 => AvatarStyle::Animal,
            2 => AvatarStyle::Abstract,
            3 => AvatarStyle::Gradient,
            _ => AvatarStyle::Pattern,
        };
        
        let url = match style {
            AvatarStyle::Initials => {
                let initials = Self::get_initials(user_name);
                format!("https://ui-avatars.com/api/?name={}&background={}&color={}&size=256", 
                    initials,
                    &background[1..],
                    &color[1..]
                )
            },
            AvatarStyle::Animal => {
                let animal_index = (hash as usize / 5) % Self::ANIMAL_AVATARS.len();
                let animal = Self::ANIMAL_AVATARS[animal_index];
                format!("https://api.dicebear.com/7.x/animalz/svg?seed={}&backgroundColor={}", 
                    animal,
                    &background[1..]
                )
            },
            AvatarStyle::Abstract => {
                format!("https://api.dicebear.com/7.x/shapes/svg?seed={}&backgroundColor={}", 
                    user_id,
                    &background[1..]
                )
            },
            AvatarStyle::Gradient => {
                format!("https://source.boringavatars.com/beam/256/{}?colors={},{}", 
                    user_id,
                    &color[1..],
                    &background[1..]
                )
            },
            AvatarStyle::Pattern => {
                format!("https://api.dicebear.com/7.x/identicon/svg?seed={}&backgroundColor={}", 
                    user_id,
                    &background[1..]
                )
            },
        };
        
        Avatar {
            style,
            color: color.to_string(),
            background: background.to_string(),
            url,
        }
    }
    
    /// 获取本地默认头像路径
    pub fn get_local_avatar(index: usize) -> String {
        // 本地预设头像（可以存储在静态资源中）
        const LOCAL_AVATARS: [&str; 10] = [
            "/assets/avatars/avatar_01.svg",
            "/assets/avatars/avatar_02.svg",
            "/assets/avatars/avatar_03.svg",
            "/assets/avatars/avatar_04.svg",
            "/assets/avatars/avatar_05.svg",
            "/assets/avatars/avatar_06.svg",
            "/assets/avatars/avatar_07.svg",
            "/assets/avatars/avatar_08.svg",
            "/assets/avatars/avatar_09.svg",
            "/assets/avatars/avatar_10.svg",
        ];
        let idx = index % LOCAL_AVATARS.len();
        LOCAL_AVATARS.get(idx).copied().unwrap_or(LOCAL_AVATARS[0]).to_string()
    }
    
    /// 从名字获取首字母
    fn get_initials(name: &str) -> String {
        let parts: Vec<&str> = name.split_whitespace().collect();
        if parts.is_empty() {
            return "U".to_string();
        }
        
        let mut initials = String::new();
        
        // 如果是中文名字，取前两个字符
        if name.chars().any(|c| (c as u32) > 0x4E00 && (c as u32) < 0x9FFF) {
            let chars: Vec<char> = name.chars().collect();
            if chars.len() >= 2 {
                initials.push(chars[0]);
                initials.push(chars[1]);
            } else if !chars.is_empty() {
                initials.push(chars[0]);
            }
        } else {
        // 英文名字，取每个单词的首字母（最多2个）
        for part in parts.iter().take(2) {
            if let Some(first_char) = part.chars().next() {
                initials.push(first_char.to_uppercase().next().unwrap_or(first_char));
            }
        }
        }
        
        if initials.is_empty() {
            initials = "U".to_string();
        }
        
        initials
    }
    
    /// 简单的哈希函数
    fn simple_hash(s: &str) -> u32 {
        s.bytes().fold(0u32, |acc, b| {
            acc.wrapping_mul(31).wrapping_add(b as u32)
        })
    }
    
    /// 生成多个候选头像供用户选择
    pub fn generate_avatar_options(user_name: &str, user_email: &str, count: usize) -> Vec<Avatar> {
        let mut avatars = Vec::new();
        let mut rng = rand::thread_rng();
        
        // 确保每种风格至少有一个
        let styles = [
            AvatarStyle::Initials,
            AvatarStyle::Animal,
            AvatarStyle::Abstract,
            AvatarStyle::Gradient,
            AvatarStyle::Pattern,
        ];
        
        for (i, style) in styles.iter().enumerate() {
            if i >= count {
                break;
            }
            
            let (color, background) = Self::COLOR_THEMES
                .choose(&mut rng)
                .unwrap_or(&("#4ECDC4", "#E3FFF8"));
            
            let url = match style {
                AvatarStyle::Initials => {
                    let initials = Self::get_initials(user_name);
                    format!("https://ui-avatars.com/api/?name={}&background={}&color={}&size=256", 
                        initials,
                        &background[1..],
                        &color[1..]
                    )
                },
                AvatarStyle::Animal => {
                    let animal = Self::ANIMAL_AVATARS
                        .choose(&mut rng)
                        .unwrap_or(&"panda");
                    format!("https://api.dicebear.com/7.x/animalz/svg?seed={}&backgroundColor={}", 
                        animal,
                        &background[1..]
                    )
                },
                AvatarStyle::Abstract => {
                    let pattern = Self::ABSTRACT_PATTERNS
                        .choose(&mut rng)
                        .unwrap_or(&"circles");
                    format!("https://api.dicebear.com/7.x/shapes/svg?seed={}&backgroundColor={}", 
                        pattern,
                        &background[1..]
                    )
                },
                AvatarStyle::Gradient => {
                    format!("https://source.boringavatars.com/beam/256/{}{}?colors={},{}", 
                        user_email, i,
                        &color[1..],
                        &background[1..]
                    )
                },
                AvatarStyle::Pattern => {
                    format!("https://api.dicebear.com/7.x/identicon/svg?seed={}{}&backgroundColor={}", 
                        user_email, i,
                        &background[1..]
                    )
                },
            };
            
            avatars.push(Avatar {
                style: style.clone(),
                color: color.to_string(),
                background: background.to_string(),
                url,
            });
        }
        
        avatars
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_get_initials() {
        assert_eq!(AvatarService::get_initials("John Doe"), "JD");
        assert_eq!(AvatarService::get_initials("张三"), "张三");
        assert_eq!(AvatarService::get_initials("李"), "李");
        assert_eq!(AvatarService::get_initials(""), "U");
        assert_eq!(AvatarService::get_initials("Alice Bob Charlie"), "AB");
    }
    
    #[test]
    fn test_generate_random_avatar() {
        let avatar = AvatarService::generate_random_avatar("Test User", "test@example.com");
        assert!(!avatar.url.is_empty());
        assert!(!avatar.color.is_empty());
        assert!(!avatar.background.is_empty());
    }
    
    #[test]
    fn test_deterministic_avatar() {
        let avatar1 = AvatarService::generate_deterministic_avatar("user123", "Test User");
        let avatar2 = AvatarService::generate_deterministic_avatar("user123", "Test User");
        assert_eq!(avatar1.url, avatar2.url);
        assert_eq!(avatar1.color, avatar2.color);
    }
}
