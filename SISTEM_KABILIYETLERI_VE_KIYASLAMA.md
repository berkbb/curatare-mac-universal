# Curatare — Sistem Kabiliyetleri, Bakım Mimarisi ve Kapsam Denetim Raporu

> **Uygulama:** Curatare (`com.babadogantech.curatare`)  
> **Platform:** macOS 26 (Tahoe) ve üzeri — Universal Binary (`arm64` + `x86_64`)  
> **Teknoloji Yığını:** Swift 6.2, SwiftUI (Liquid Glass), AppKit, Mole Engine (`tw93/mole`)  
> **Temel İlke:** Sıfır Veri Kaybı, Tarihli Çöp Güvencesi (`DatedTrash`), Kesintisiz Geri Alınabilirlik  

---

## 1. Yönetici Özeti ve Konumlandırma

Curatare, modern macOS sistemlerinde geleneksel sistem bakım araçlarının, üçüncü taraf tescilli uygulama kaldırıcıların ve terminal tabanlı optimizasyon betiklerinin işlevlerini tek bir yüksek güvenlikli, yerel (native) ve Liquid Glass arayüzlü stüdyoda birleştiren yeni nesil bir sistem bakım merkezidir.

Bu belge; klasik macOS bakım izlencelerinin ve üçüncü taraf kaldırma araçlarının sunduğu tüm işlevlerin Curatare bünyesine nasıl dahil edildiğini, modern APFS ve Apple Silicon mimarisi doğrultusunda **%100 oranında kapsanan özellikleri**, sistem bütünlüğü ve veri güvenliği gerekçeleriyle **bilinçli olarak reddedilen unsurları** ve Curatare'nin sektöre getirdiği yenilikçi üstünlükleri kayıt altına almaktadır.

---

## 2. Karşılaştırmalı Modül Matrisi (8 Ana Sistem Alanı)

Klasik macOS bakım izlencelerinde bulunan 8 ana operasyonel alanın Curatare içerisindeki karşılıkları ve entegrasyon seviyesi aşağıdaki tabloda özetlenmiştir:

| Alan / Modül | Kapsam Oranı | Curatare Karşılığı ve Entegre Edilen Özellikler |
| :--- | :---: | :--- |
| **1. Ana Ekran / Karşılama** | **%100** | **Başlangıç Ekranı:** Mole motoru entegre sağlık puanı (100 üzerinden), hızlı temizlik, derin temizlik, sistem bakımı kısayolları ve güvenlik rozeti. |
| **2. Sistem Bakımı (Maintenance)** | **%100** | **Sistem Bakımı Paneli:** 11 kritik bakım görevinin tamamı (APFS doğrulama, Spotlight sıfırlama, Time Machine inceltme, Mail Envelope Index, CUPS yazıcı kuyruğu, QuickLook, DNS, Fontlar, IconServices, LaunchServices, Günlükler). |
| **3. Yardımcı İzlenceler (Utilities)** | **%100** | **Gizli Sistem Araçları & Sağlama Toplamı:** 7 gizli Apple izlencesi başlatıcı kartı, sürükle-bırak MD5 / SHA-1 / SHA-256 akış hesaplayıcı ve otomatik eşleşme doğrulayıcı, APFS birim sağlık kartı. |
| **4. Dosyalar ve Önbellekler (Cleaning)** | **%100+** | **Kitaplık Kalıntıları, Tarayıcılar ve Geliştirici Ekosistemleri:** 5-Gruplu (A–E) derin yetim tespiti, `containermanagerd` kalıntıları, 12 programlama dili önbelleği, yerel AI modelleri (Ollama, LM Studio vb.), Xcode arşivleri. |
| **5. Güvenlik ve Bütünlük (Security)** | **%100** | **macOS Güvenlik Durumu Göstergesi:** Canlı SIP (Sistem Bütünlüğü Koruması), FileVault disk şifreleme, Gatekeeper uygulama denetimi, XProtect ve XProtect Remediator sürüm takibi, Kilit Modu (Lockdown Mode). |
| **6. Arama ve Disk Analizi (Search)** | **%100+** | **Disk Analizi Stüdyosu:** İlkel dosya aramaları yerine, evrensel Mach-O `analyze-go` motoruyla çalışan çok katmanlı, gerçek zamanlı disk ağacı analizi ve Finder entegrasyonu. |
| **7. İnce Ayarlar (Parameters / Tweaks)** | **%100** | **macOS İnce Ayarları:** 20 adet sistem parametresi (Finder gizli dosyalar, başlıkta tam yol, Dock ayırıcı boşluk `spacer-tile`, USB'de `.DS_Store` engelleme, `Ctrl+Cmd` pencere taşıma, hızlı tuş yineleme, TextEdit boş belge açılışı, ekran görüntüsü konumu ve pencere gölgesi ayarları). |
| **8. Sistem Merkezi (Info / System Center)** | **%100** | **Gelişmiş Sistem Merkezi (5 Sekme):** Donanım (P/E çekirdek dağılımı, GPU, ekran çözünürlüğü), Bellek (renkli Memory Pressure göstergesi, Swap durumu ve "Belleği Rahatlat / purge" butonu), Birimler (APFS Snapshot ve Data hacmi), Sistem & Kimlik (Build ID, Uptime) ve Profil Dışa Aktarıcı (`system_profiler` JSON/Metin). |

---

## 3. Ayrıntılı Kabiliyet İncelemesi

### A. Sistem Bakımı ve Onarım Görevleri
Sistem Bakımı panelinde yer alan 11 görev, macOS'un dahili bakım mekanizmalarını güvenli biçimde tetikler:
1. **APFS Dosya Sistemi Bütünlük Doğrulaması:** Canlı birim üzerinde salt-okunur modda `fsck_apfs -n` çalıştırarak dosya sistemi yapısını, kapsayıcıları ve nesne haritasını denetler.
2. **Spotlight Arama Dizinini Sıfırlama:** Takılan veya eksik sonuç veren arama indeksini `mdutil -E` ile temizleyerek meta veri motorunun baştan indeksleme yapmasını sağlar.
3. **Time Machine Yerel Enstantanelerini İnceltme:** `tmutil thinlocalsnapshots` çağrısıyla yerel diskte gereksiz biriken APFS anlık görüntülerini güvenle inceltir ve disk alanı açar.
4. **Apple Mail Zarf Dizini (Envelope Index) Sıfırlama:** Posta kutusu aramaları yavaşladığında veya e-postalar görünmediğinde zarf veritabanı dosyalarını tarihli çöpe taşıyarak Mail'in veritabanını hatasız yeniden inşa etmesini sağlar.
5. **CUPS Yazdırma Kuyruğunu Temizleme:** Yazıcı sırasında takılı kalan ve sistemi kilitleyen yazdırma işlerini `cancel -a -` komutuyla anında sonlandırır.
6. **QuickLook Küçük Resim Önbelleğini Sıfırlama:** Dosya önizlemeleri bozulduğunda `qlmanage -r cache` komutuyla önbellek daemon'ını sıfırlar.
7. **DNS Çözümleyici Önbelleği Temizleme:** Ağ yönlendirme veya alan adı çözümleme sorunlarında `mDNSResponder` servisine kesintisiz `HUP` sinyali gönderir.
8. **Sistem ve Kullanıcı Yazı Tipi (Font) Önbellekleri:** Bozuk karakterler veya yazı tipi çakışmalarında `atsutil` önbelleğini yeniler.
9. **Simge (IconServices) Önbelleği Sıfırlama:** Finder üzerinde beyaz veya hatalı görünen uygulama simgelerini onarır.
10. **LaunchServices (Birlikte Aç) Veritabanı Sıfırlama:** Dosyaların yanlış uygulamalarla açılması veya menüde mükerrer uygulamaların listelenmesi sorununu çözer.
11. **Sistem Günlükleri ve Tanılama Raporları Temizliği:** Şişen çökme günlüklerini ve sistem loglarını güvenle temizler.

### B. Yardımcı Programlar ve Gizli Araçlar
1. **Gizli Sistem İzlenceleri Başlatıcı:** macOS'un menülerde doğrudan göstermediği derin sistem araçlarını (Kablosuz Ağ Tanılama, Dizin İzlencesi, ColorSync Yardımcısı, Arşiv İzlencesi, Anahtar Zinciri Erişimi, Geri Bildirim Yardımcısı vb.) tek tıkla başlatır.
2. **Akış Tabanlı Dosya Sağlama Toplamı (Checksum / Hash):** Büyük dosyalarda dahi belleği şişirmeyen `FileHandle` akışı ile MD5, SHA-1 ve SHA-256 özetlerini milisaniyeler içinde hesaplar; panodan alınan veya kullanıcı tarafından girilen özetlerle otomatik harf duyarsız eşleşme doğrulaması yapar.

### C. macOS İnce Ayarları (Tweaks)
* **Finder & Masaüstü:** Gizli dosyaları göster/gizle, pencere başlık çubuğunda tam POSIX yolunu göster, masaüstü simgelerini aç/kapa.
* **Dock:** Yalnızca çalışan uygulamaları göster, otomatik gizleme gecikmesini kaldır, şeffaf ayırıcı boşluk (`spacer-tile`) ekle/kaldır.
* **Pencere ve Etkileşim:** Pencereleri `Ctrl+Cmd` tuşlarına basarak başlık çubuğu yerine herhangi bir yerinden sürükleme (`NSWindowShouldDragOnGesture`), aksan pop-up'ı yerine hızlı tuş yineleme (`ApplePressAndHoldEnabled`), TextEdit'in doğrudan boş belgeyle açılması.
* **Depolama ve Harici Sürücüler:** Harici USB sürücülere ve ağ paylaşımlarına `.DS_Store` yazılmasını engelleme (`DSDontWriteUSBStores`).
* **Ekran Alıntıları:** Ekran görüntüsü formatı (PNG, JPG, PDF, TIFF), pencere gölgelerini devre dışı bırakma ve hedef kaydetme dizini seçimi.

### D. Sistem Merkezi ve Donanım Analitiği
* **Donanım:** Model adı, Model ID, işlemci çipi, mimari, Performans ve Verimlilik (P/E) çekirdek dağılımı, GPU çekirdek sayısı, ekran çözünürlüğü, donanım UUID ve seri numarası.
* **Bellek (RAM):** Fiziksel bellek, bellek türü, kullanılan / yerleşik (wired) / önbelleğe alınan miktarlar, dinamik renkli Bellek Baskısı (Memory Pressure) göstergesi, Takas (Swap) boyutu ve tek tıkla inaktif sayfaları RAM'den boşaltan "Belleği Rahatlat (purge)" çağrısı.
* **Birimler:** APFS Kilitli Sistem Birimi (Boot Snapshot) ve Veri Birimi (`/System/Volumes/Data`) doluluk oranları.
* **Sistem & Kimlik:** macOS sürümü, Build ID (Yapı Numarası), Darwin çekirdek sürümü, Finder ve AppleScript sürümleri, Uptime (açık kalma süresi) ve kullanıcı kimlik dökümü.
* **Profil Dışa Aktarma:** `system_profiler` donanım, bellek, depolama ve yazılım raporlarını Metin veya JSON olarak önizleme ve `.spx` / `.txt` olarak diske kaydetme.

### E. Yerel Uygulama Kaldırıcı ve SmartDelete Entegrasyonu
Üçüncü taraf tescilli kaldırıcıların yerini alan Curatare Uygulama Kaldırıcı mimarisi:
* Sistemdeki tüm Uygulamaları, Widget'ları ve Eklentileri (PreferencePanes, QuickLook, Audio Components vb.) otomatik listeler.
* Herhangi bir uygulamayı arayüze veya Dock simgesine sürükleyip bırakarak 30'u aşkın konumdaki ilgili kapsayıcı, önbellek, tercih ve destek dosyalarını canlı boyutlarıyla inceler.
* **SmartDelete (Çöp İzleyici):** Finder'da bir uygulama Çöp Sepeti'ne taşındığında arka planda devreye girerek kullanıcıya ilgili kütüphane artıklarını temizleme olanağı tanır.

---

## 4. Bilinçli Olarak Reddedilen Özellikler ve Güvenlik Gerekçeleri

Curatare mimarisi gereği, modern Apple Silicon ve APFS güvenliğini tehdit eden ya da geçerliliğini yitirmiş özellikler bilinçli olarak reddedilmiştir:

| Reddedilen Özellik | Neden Reddedildi? | Curatare Güvenlik Standardı |
| :--- | :--- | :--- |
| **Kalıcı Dosya Parçalama (Shredding / DoD 7-Pass Erase)** | Modern SSD/NVMe disklerdeki *Wear-Leveling* (Aşınma Dengeleme) nedeniyle üzerine yazma işlemi hedeflenen fiziksel hücreyi garanti edemez ve SSD ömrünü yıpratır. | **Dated-Trash-Only Kuralı:** Hiçbir kullanıcı dosyası kalıcı olarak silinmez (`rm -rf` yasaktır). Her şey `~/.Trash/Curatare-TARİH` altına geri yüklenebilir şekilde taşınır. |
| **Eski HFS+ / macOS 10.x Mirası Görevler** | Disk birleştirme (defrag) ve eski NetInfo önbellekleri APFS dosya sisteminde tamamen geçersizdir ve diske zarar verebilir. | Yalnızca modern APFS kapsayıcı ve hacim yapılarıyla uyumlu araçlar kullanılır. |
| **Kök Dizin ve Kext Manipülasyonları** | Apple Silicon'un İmzalı Sistem Birimi (SSV) ve Sistem Bütünlüğü Koruması (SIP) mimarisini delmeye yönelik kararsız müdahaleler macOS'u başlatılamaz hale getirebilir. | Sistem dosyaları (`/System/Library`, Apple sistem daemon'ları) katı koruma kuralı (`ProtectionRules`) altındadır. |

---

## 5. Curatare'nin Fark Yaratan Ek Yetenekleri

Curatare, geleneksel bakım ve kaldırma araçlarının sunduğu taban yeteneklerin çok ötesine geçerek şu benzersiz özellikleri barındırır:

1. **Gömülü Mole Motoru (`tw93/mole`):** Hızlı derin temizlik, proje artıkları temizliği, evrensel Go yardımcıları (`analyze-go`, `status-go`) ve tek tıkla GitHub üzerinden güncellenebilen bağımsız motor.
2. **Kapsamlı Geliştirici ve AI Ekosistemleri Temizliği:** 12 programlama dili ekosistemi (pip, cargo, npm, gradle, maven, swiftpm, pub, ccache, go-build vb.), Homebrew indirme önbelleği ve yerel yapay zeka modelleri (Ollama, LM Studio, Hugging Face).
3. **5-Grup Kütüphane Yetim Mimarisi (`library_clean.md`):** Yalnızca yüzeysel önbellekleri değil; derleme ve test artıklarını (Grup A), ölü kapsayıcı meta verilerini (Grup B), bare ikili çalıştırma izlerini (Grup C), yetim uygulama verilerini (Grup D) ve yetim sistem servislerini (Grup E) tespit eder.
4. **Kesintisiz Geri Alınabilirlik:** Yapılan her temizlik işlemi `~/.Trash` içinde zaman damgalı bir klasörde `manifest.json` dosyasıyla saklanır. Kullanıcı "Tarihli Çöp Turları" ekranından tek tıkla herhangi bir temizliği orijinal konumuna geri yükleyebilir.
5. **Babadogan Mac Araçları Aile Entegrasyonu:** Arhivar, Copiator, Descarcator ve Curatare arasında karşılıklı koruma ve entegrasyon.
6. **Üç Dilde Kusursuz Yerelleştirme:** Türkçe (varsayılan), İngilizce ve Rumence dillerinde tam 1:1 katalog uyumu.

---

## 6. Sonuç ve Uyumluluk Beyanı

Curatare; sektördeki referans sistem bakım izlencelerinin ve üçüncü taraf kaldırma araçlarının barındırdığı **geçerli, modern ve güvenli tüm yetenekleri bünyesinde toplamış**, üzerine güçlü geliştirici araçları, modern yapay zeka önbellek temizleyicileri ve geri alınabilir tarihli çöp güvencesini eklemiştir.

Uygulama, macOS 26 Tahoe ve gelecekteki macOS sürümleri için eksiksiz, kararlı ve yüksek güvenceli bir sistem stüdyosu olarak hizmet vermektedir.
