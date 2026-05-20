
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

CREATE TABLE Restoranlar (
    RestoranID INT IDENTITY(1,1), 
    RestoranAdi VARCHAR(100) NOT NULL,
    Adres TEXT NOT NULL,
    RestoranPuani DECIMAL(2, 1) DEFAULT 1.0,
    IsActive INT DEFAULT 1,
    
    CONSTRAINT PK_Restoranlar PRIMARY KEY (RestoranID), 
    CONSTRAINT CHK_RestoranPuani CHECK (RestoranPuani BETWEEN 1.0 AND 5.0) 
);

CREATE TABLE Urunler (
    UrunID INT IDENTITY(1,1), 
    RestoranID INT NOT NULL,  
    UrunAdi VARCHAR(100) NOT NULL,
    Acýklama TEXT,
    Fiyat DECIMAL(10, 2) NOT NULL,
    IsActive INT DEFAULT 1,   

    CONSTRAINT PK_Urunler PRIMARY KEY (UrunID),
    
    CONSTRAINT FK_Urunler_Restoranlar FOREIGN KEY (RestoranID) 
        REFERENCES Restoranlar(RestoranID),
        
    CONSTRAINT CHK_UrunFiyat CHECK (Fiyat > 0)
);