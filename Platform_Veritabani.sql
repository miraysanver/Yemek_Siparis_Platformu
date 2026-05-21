

-- TABLO TEMÝZLEME (Hata almamak için baðýmlýlýk sýrasýna göre silme)
IF OBJECT_ID('dbo.SiparisDetaylari', 'U') IS NOT NULL DROP TABLE dbo.SiparisDetaylari;
IF OBJECT_ID('dbo.Siparisler', 'U') IS NOT NULL DROP TABLE dbo.Siparisler;
IF OBJECT_ID('dbo.Bagislar', 'U') IS NOT NULL DROP TABLE dbo.Bagislar;
IF OBJECT_ID('dbo.AskidaHavuz', 'U') IS NOT NULL DROP TABLE dbo.AskidaHavuz;
IF OBJECT_ID('dbo.Urunler', 'U') IS NOT NULL DROP TABLE dbo.Urunler;
IF OBJECT_ID('dbo.Restoranlar', 'U') IS NOT NULL DROP TABLE dbo.Restoranlar;
IF OBJECT_ID('dbo.Kullanicilar', 'U') IS NOT NULL DROP TABLE dbo.Kullanicilar;
GO

-- 1. KULLANICILAR TABLOSU
CREATE TABLE Kullanicilar (
    KullaniciID INT IDENTITY(1,1), 
    Ad VARCHAR(50) NOT NULL,
    Soyad VARCHAR(50) NOT NULL,
    Eposta VARCHAR(100) NOT NULL,
    Telefon VARCHAR(15) NOT NULL,
    Rol VARCHAR(20) NOT NULL, 
    Bakiye DECIMAL(10, 2) DEFAULT 0.00,
    IsVerified BIT DEFAULT 0, 
    IsActive INT DEFAULT 1, 
    
    CONSTRAINT PK_Kullanicilar PRIMARY KEY (KullaniciID), 
    CONSTRAINT UQ_KullaniciEposta UNIQUE (Eposta),
    CONSTRAINT UQ_KullaniciTelefon UNIQUE (Telefon),
    CONSTRAINT CHK_KullaniciBakiye CHECK (Bakiye >= 0)
);
GO

-- 2. RESTORANLAR TABLOSU
CREATE TABLE Restoranlar (
    RestoranID INT IDENTITY(1,1), 
    RestoranAdi VARCHAR(100) NOT NULL,
    Adres TEXT NOT NULL,
    RestoranPuani DECIMAL(2, 1) DEFAULT 1.0,
    IsActive INT DEFAULT 1,
    
    CONSTRAINT PK_Restoranlar PRIMARY KEY (RestoranID), 
    CONSTRAINT CHK_RestoranPuani CHECK (RestoranPuani BETWEEN 1.0 AND 5.0)
);
GO

-- 3. ÜRÜNLER TABLOSU
CREATE TABLE Urunler (
    UrunID INT IDENTITY(1,1), 
    RestoranID INT NOT NULL,  
    UrunAdi VARCHAR(100) NOT NULL,
    Aciklama TEXT,
    Fiyat DECIMAL(10, 2) NOT NULL,
    IsActive INT DEFAULT 1,   

    CONSTRAINT PK_Urunler PRIMARY KEY (UrunID),
    CONSTRAINT FK_Urunler_Restoranlar FOREIGN KEY (RestoranID) REFERENCES Restoranlar(RestoranID),
    CONSTRAINT CHK_UrunFiyat CHECK (Fiyat > 0)
);
GO

-- 4. ASKIDA YEMEK HAVUZU TABLOSU
CREATE TABLE AskidaHavuz (
    HavuzID INT IDENTITY(1,1),
    ToplamBakiye DECIMAL(10, 2) DEFAULT 0.00,
    SonGuncellemeTarihi DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_AskidaHavuz PRIMARY KEY (HavuzID),
    CONSTRAINT CHK_HavuzToplamBakiye CHECK (ToplamBakiye >= 0)
);
GO

-- 5. BAÐIÞLAR TABLOSU
CREATE TABLE Bagislar (
    BagisID INT IDENTITY(1,1),
    BagisciID INT NULL, 
    BagisMiktar DECIMAL(10, 2) NOT NULL,
    IsAnonymous BIT DEFAULT 0,  
    BagisTarihi DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_Bagislar PRIMARY KEY (BagisID),
    CONSTRAINT FK_Bagislar_Kullanicilar FOREIGN KEY (BagisciID) REFERENCES Kullanicilar(KullaniciID),
    CONSTRAINT CHK_BagisMiktar CHECK (BagisMiktar > 0)
);
GO

-- 6. SÝPARÝÞLER TABLOSU
CREATE TABLE Siparisler (
    SiparisID INT IDENTITY(1,1),
    MusteriID INT NOT NULL,        
    RestoranID INT NOT NULL,      
    ToplamTutar DECIMAL(10, 2) NOT NULL,
    OdemeYontemi VARCHAR(30) NOT NULL, 
    SiparisDurumu VARCHAR(30) DEFAULT 'Hazirlaniyor', 
    SiparisTarihi DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_Siparisler PRIMARY KEY (SiparisID),
    CONSTRAINT FK_Siparisler_Kullanicilar FOREIGN KEY (MusteriID) REFERENCES Kullanicilar(KullaniciID),
    CONSTRAINT FK_Siparisler_Restoranlar FOREIGN KEY (RestoranID) REFERENCES Restoranlar(RestoranID),
    CONSTRAINT CHK_SiparisToplamTutar CHECK (ToplamTutar > 0)
);
GO

-- 7. SÝPARÝÞ DETAYLARI TABLOSU
CREATE TABLE SiparisDetaylari (
    SiparisDetayID INT IDENTITY(1,1),
    SiparisID INT NOT NULL,      
    UrunID INT NOT NULL,          
    Adet INT NOT NULL DEFAULT 1,
    BirimFiyat DECIMAL(10, 2) NOT NULL,

    CONSTRAINT PK_SiparisDetaylari PRIMARY KEY (SiparisDetayID),
    CONSTRAINT FK_SiparisDetaylari_Siparisler FOREIGN KEY (SiparisID) REFERENCES Siparisler(SiparisID),
    CONSTRAINT FK_SiparisDetaylari_Urunler FOREIGN KEY (UrunID) REFERENCES Urunler(UrunID),
    CONSTRAINT CHK_SDetayAdet CHECK (Adet > 0),
    CONSTRAINT CHK_SDetayBirimFiyat CHECK (BirimFiyat > 0)
);
GO

-- Havuz baþlangýç kaydý
INSERT INTO AskidaHavuz (ToplamBakiye) VALUES (0.00);
GO

-- Baðýþ yapýldýðýnda havuzu otomatik arttýran trigger
CREATE TRIGGER TRG_BagisSonrasiHavuzGuncelle
ON Bagislar
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @EklenenMiktar DECIMAL(10,2);
    SELECT @EklenenMiktar = BagisMiktar FROM inserted;
    
    UPDATE AskidaHavuz
    SET ToplamBakiye = ToplamBakiye + @EklenenMiktar,
        SonGuncellemeTarihi = GETDATE()
    WHERE HavuzID = 1;
END;
GO

-- Askýda Sipariþ verildiðinde havuzdan bakiye düþen trigger
CREATE TRIGGER TRG_AskidaSiparisHavuzDus
ON Siparisler
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SiparisTutari DECIMAL(10,2);
    DECLARE @OdemeTipi VARCHAR(30);
    
    SELECT @SiparisTutari = ToplamTutar, @OdemeTipi = OdemeYontemi FROM inserted;

    -- Eðer kolonda typo varsa ToplamTutar yapalým
    SELECT @SiparisTutari = ToplamTutar, @OdemeTipi = OdemeYontemi FROM inserted;

    IF @OdemeTipi = 'AskidaYemek'
    BEGIN
        DECLARE @MevcutHavuz DECIMAL(10,2);
        SELECT @MevcutHavuz = ToplamBakiye FROM AskidaHavuz WHERE HavuzID = 1;
        
        IF @MevcutHavuz >= @SiparisTutari
        BEGIN
            UPDATE AskidaHavuz
            SET ToplamBakiye = ToplamBakiye - @SiparisTutari,
                SonGuncellemeTarihi = GETDATE()
            WHERE HavuzID = 1;
        END
        ELSE
        BEGIN
            RAISERROR('Hata: Askýda yemek havuzunda yeterli bakiye bulunmamaktadýr!', 16, 1);
            ROLLBACK TRANSACTION;
        END
    END
END;
GO

-- 20 Adet Özel Kullanýcý
INSERT INTO Kullanicilar (Ad, Soyad, Eposta, Telefon, Rol, Bakiye, IsVerified, IsActive) VALUES
('Elanur', 'Çiftçi', 'elanur.ciftci@gmail.com', '05321111111', 'Musteri', 250.00, 0, 1),
('Miray', 'Aslan', 'miray.aslan@gmail.com', '05322222222', 'Musteri', 500.00, 0, 1),
('Can', 'Demir', 'can.demir@gmail.com', '05323333333', 'Musteri', 50.00, 0, 1),
('Merve', 'Kaya', 'merve.kaya@gmail.com', '05324444444', 'Musteri', 0.00, 1, 1), 
('Gamze', 'Özaydýn', 'gamze.ozaydin@gmail.com', '05325555555', 'Musteri', 15.00, 1, 1),  
('Eda', 'Þahin', 'eda.sahin@gmail.com', '05326666666', 'Musteri', 750.00, 0, 1),
('Hasan', 'Yýldýz', 'hasan.yildiz@gmail.com', '05327777777', 'Musteri', 120.00, 0, 1),
('Zeynep Naz', 'Aþan', 'zeynep.naz.asan@gmail.com', '05328888888', 'Musteri', 0.00, 1, 1), 
('Onur', 'Arslan', 'onur.arslan@gmail.com', '05329999999', 'Musteri', 340.00, 0, 1),
('Ramazan', 'Þanver', 'ramazan.sanver@gmail.com', '05331111111', 'Musteri', 1000.00, 0, 1),
('Emre', 'Kurt', 'emre.kurt@gmail.com', '05332222222', 'Musteri', 45.00, 0, 1),
('Pelýn', 'Ay', 'pelin.ay@gmail.com', '05333333333', 'Musteri', 0.00, 1, 1),       
('Emine', 'Tebelleþ', 'emine.tebelles@gmail.com', '05334444444', 'Musteri', 150.00, 0, 1),
('Gökhan', 'Öztürk', 'gokhan.ozturk@gmail.com', '05335555555', 'Musteri', 60.00, 0, 1),
('Büþra', 'Aðdað', 'busra.agdag@gmail.com', '05336666666', 'Musteri', 0.00, 1, 1),       
('Murat', 'Tekin', 'murat.tekin@gmail.com', '05337777777', 'RestoranYetkilisi', 0.00, 0, 1),
('Ayþenaz', 'Kocatürk', 'aysenaz.kocaturk@gmail.com', '05338888888', 'RestoranYetkilisi', 0.00, 0, 1),
('Ali', 'Yavuz', 'ali.yavuz@gmail.com', '05339999999', 'Kurye', 0.00, 0, 1),
('Mehmet', 'Eren', 'mehmet.eren@gmail.com', '05341111111', 'Kurye', 0.00, 0, 1),
('Fatma', 'Bulut', 'fatma.bulut@gmail.com', '05342222222', 'Kurye', 0.00, 0, 1);
GO

-- 5 Adet Özel Restoran
INSERT INTO Restoranlar (RestoranAdi, Adres, RestoranPuani, IsActive) VALUES
('Mosh Burger', 'Yalova Çýnarcýk No:12', 4.5, 1),
('Yýldýz Lahmacun', 'Yalova Merkez No:45', 4.2, 1),
('Ýstanbul Döner', 'Yalova Çiftlikköy No:88', 3.9, 1),
('Saðlýk Cafe', 'Yalova Kadýköy No:3', 4.7, 1),
('Yeþil Baklava', 'Yalova Merkez No:7', 4.8, 1);
GO

-- Restoran Menüleri (50 Adet Ürün)
INSERT INTO Urunler (RestoranID, UrunAdi, Aciklama, Fiyat, IsActive) VALUES
(1, 'Klasik Burger', '150gr dana köfte, marul, turþu, özel sos', 180.00, 1),
(1, 'Cheeseburger', '150gr dana köfte, çedar peyniri, hardal', 195.00, 1),
(1, 'Tavuk Burger', 'Çýtýr tavuk göðsü, mayonez, marul', 150.00, 1),
(1, 'Barbekü Soslu Burger', 'Karamelize soðan, barbekü sos, füme et', 220.00, 1),
(1, 'Acýlý Hot Burger', 'Jalapeno biberi, acý sos, dana köfte', 200.00, 1),
(1, 'Mantar Soslu Burger', 'Kremalý mantar sosu, erimiþ peynir', 210.00, 1),
(1, 'Büyük Boy Patates', 'Baharatlý çýtýr patates kýzartmasý', 60.00, 1),
(1, 'Soðan Halkasý (8li)', 'Çýtýr kaplamalý altýn soðan halkalarý', 50.00, 1),
(1, 'Kutu Kola', 'Soðuk içecek', 40.00, 1),
(1, 'Ayran', 'Milli içeceðimiz', 25.00, 1),
(2, 'Çýtýr Lahmacun', 'Özel harçlý Antep usulü lahmacun', 65.00, 1),
(2, 'Kaþarlý Lahmacun', 'Erimiþ kaþar peynirli lahmacun', 80.00, 1),
(2, 'Kýymalý Pide', 'Bol malzemeli Karadeniz usulü kýymalý', 160.00, 1),
(2, 'Kuþbaþýlý Pide', 'Dana kuþbaþý etli ve biberli pide', 190.00, 1),
(2, 'Karýþýk Pide', 'Kýyma, kuþbaþý ve kaþarýn muhteþem uyumu', 210.00, 1),
(2, 'Mercimek Çorbasý', 'Tereyaðlý süzme mercimek çorbasý', 70.00, 1),
(2, 'Gavurdaðý Salatasý', 'Cevizli ve narlý özel salata', 75.00, 1),
(2, 'Künefe', 'Sýcak, þerbetli ve peynirli Hatay künefesi', 110.00, 1),
(2, 'Yayýk Ayraný', 'Köpüklü açýk ayran', 30.00, 1),
(2, 'Þalgam Suyu', 'Acýlý / Acýsýz Adana þalgamý', 30.00, 1),
(3, 'Tavuk Döner Dürüm', 'Hatay usulü soslu tavuk dürüm', 110.00, 1),
(3, 'Et Döner Dürüm', '100gr yaprak et döner, lavaþ ekmeðinde', 180.00, 1),
(3, 'G tombik Et Döner', 'Tombik ekmek arasý et döner', 170.00, 1),
(3, 'Ýskender Kebap', 'Tereyaðlý, soslu enfes et iskender', 260.00, 1),
(3, 'Pilav Üstü Tavuk Döner', 'Tereyaðlý pilav ve çýtýr tavuk döner', 140.00, 1),
(3, 'Pilav Üstü Et Döner', 'Tereyaðlý pilav ve yaprak et döner', 210.00, 1),
(3, 'Patates Kýzartmasý', 'Tuzlu parmak patates', 55.00, 1),
(3, 'Sütlaç', 'Fýrýnlanmýþ anne usulü sütlaç', 80.00, 1),
(3, 'Kutu Fanta', 'Portakallý gazlý içecek', 40.00, 1),
(3, 'Su (0.5L)', 'Doðal kaynak suyu', 15.00, 1),
(4, 'Sezar Salata', 'Izgara tavuk göðsü, kruton ekmek, sezar sos', 165.00, 1),
(4, 'Ton Balýklý Salata', 'Mýsýr, Akdeniz yeþillikleri ve ton balýðý', 175.00, 1),
(4, 'Kinoa & Avokado Salatasý', 'Diyet yapanlar için yüksek lifli salata', 190.00, 1),
(4, 'Izgara Köfte Tabaðý', 'Yanýnda fýrýn sebze ile 6 adet ýzgara köfte', 240.00, 1),
(4, 'Sebzeli Fit Wrap', 'Tam buðday lavaþýnda sote sebzeler', 130.00, 1),
(4, 'Tavuklu Fit Wrap', 'Lavaþ arasý ýzgara tavuk ve mantar', 155.00, 1),
(4, 'Mercimek Köftesi Tabaðý', 'Yeþillikler eþliðinde 8 adet mercimek köftesi', 95.00, 1),
(4, 'Meyve Tabaðý', 'Mevsim meyveleri karýþýmý', 85.00, 1),
(4, 'Taze Sýkýlmýþ Portakal Suyu', 'C vitamins deposu %100 doðal', 65.00, 1),
(4, 'Detoks Suyu', 'Salatalýk, nane ve limonlu yeþil detoks', 55.00, 1),
(5, 'Adana Kebap', 'Zýrh kýymasý, közlenmiþ biber ve domates ile', 250.00, 1),
(5, 'Urfa Kebap', 'Acýsýz enfes zýrh kebabý', 250.00, 1),
(5, 'Ali Nazik Kebabý', 'Beðendi yataðýnda lokum gibi sote et', 290.00, 1),
(5, 'Tavuk Þiþ', 'Marine edilmiþ tavuk göðsü küpleri', 180.00, 1),
(5, 'Çöp Þiþ', 'Köz soðan ve lavaþ eþliðinde dana çöp þiþ', 270.00, 1),
(5, 'Ýçli Köfte (Adet)', 'Antep usulü bol cevizli içli köfte', 50.00, 1),
(5, 'Fýstýklý Baklava (4 Dilim)', 'Orijinal Antep fýstýklý havuç dilim baklava', 140.00, 1),
(5, 'Havuç Dilim Baklava (1 Dilim)', 'Yanýnda dondurma ile servis edilir', 120.00, 1),
(5, 'Ezme Salata', 'Ýnce kýyýlmýþ acýlý Antep ezmesi', 60.00, 1),
(5, 'Kutu Sprite', 'Limon aromalý gazlý içecek', 40.00, 1);

GO

INSERT INTO Bagislar (BagisciID, BagisMiktar, IsAnonymous) VALUES (1, 500.00, 0);
INSERT INTO Bagislar (BagisciID, BagisMiktar, IsAnonymous) VALUES (2, 1500.00, 1);
INSERT INTO Bagislar (BagisciID, BagisMiktar, IsAnonymous) VALUES (6, 1000.00, 0);
INSERT INTO Bagislar (BagisciID, BagisMiktar, IsAnonymous) VALUES (10, 2000.00, 1);
GO 

-- 100 ADET SÝPARÝÞ HAREKETÝ DÖNGÜSÜ
DECLARE @Sayac INT = 1;
DECLARE @SecilenMusteri INT;
DECLARE @SecilenRestoran INT;
DECLARE @SecilenUrun INT;
DECLARE @UrunFiyati DECIMAL(10,2);
DECLARE @OdemeMethodu VARCHAR(30);
DECLARE @SiparisAdedi INT;

WHILE @Sayac <= 100
BEGIN
    SET @SecilenRestoran = (@Sayac % 5) + 1; 
    
    IF @Sayac % 5 = 0
    BEGIN
        -- Ýhtiyaç sahipleri havuzdan sadece ucuz ürünleri söylesin
        SET @SecilenRestoran = CASE (@Sayac % 2) WHEN 0 THEN 2 ELSE 3 END;
        SET @SecilenUrun = ((@SecilenRestoran - 1) * 10) + (@Sayac % 4) + 1; 
        SET @SiparisAdedi = 1; 
        
        SET @SecilenMusteri = CASE (@Sayac % 5)
            WHEN 0 THEN 4 WHEN 1 THEN 5 WHEN 2 THEN 8 WHEN 3 THEN 12 ELSE 15 END;
        SET @OdemeMethodu = 'AskidaYemek';
    END
    ELSE
    BEGIN
        SET @SecilenUrun = ((@SecilenRestoran - 1) * 10) + (@Sayac % 10) + 1;
        SET @SiparisAdedi = (@Sayac % 2) + 1; 
        SET @SecilenMusteri = (@Sayac % 10) + 1;
        SET @OdemeMethodu = CASE (@Sayac % 3) WHEN 0 THEN 'Kredi Karti' WHEN 1 THEN 'Nakit' ELSE 'Kredi Karti' END;
    END
    
    SELECT @UrunFiyati = Fiyat FROM Urunler WHERE UrunID = @SecilenUrun;

    INSERT INTO Siparisler (MusteriID, RestoranID, ToplamTutar, OdemeYontemi, SiparisDurumu)
    VALUES (@SecilenMusteri, @SecilenRestoran, @UrunFiyati * @SiparisAdedi, @OdemeMethodu, 'Teslim Edildi');

    DECLARE @EnSonSiparisID INT = SCOPE_IDENTITY();

    INSERT INTO SiparisDetaylari (SiparisID, UrunID, Adet, BirimFiyat)
    VALUES (@EnSonSiparisID, @SecilenUrun, @SiparisAdedi, @UrunFiyati);

    SET @Sayac = @Sayac + 1;
END;
GO